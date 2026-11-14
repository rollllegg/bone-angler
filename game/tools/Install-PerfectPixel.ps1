$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$config = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json).perfect_pixel
$toolRoot = Join-Path $projectRoot '.tools\perfect-pixel'
$sourceRoot = Join-Path $toolRoot ('perfectPixel-' + $config.revision)
$archive = Join-Path $toolRoot $config.file
New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null

if (-not (Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -Uri $config.url -OutFile $archive -UseBasicParsing
}
$actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $config.sha256) {
    throw 'PerfectPixel archive checksum mismatch. Keep it for inspection and download a verified copy.'
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'src\perfect_pixel\perfect_pixel.py'))) {
    Expand-Archive -LiteralPath $archive -DestinationPath $toolRoot
}

$python = Join-Path $toolRoot 'venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # Reuse compatible local libraries; any missing dependencies stay in this venv.
    & python -m venv --system-site-packages (Join-Path $toolRoot 'venv')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create the PerfectPixel Python environment.' }
}
& $python -c "import cv2, numpy, PIL"
if ($LASTEXITCODE -ne 0) {
    & $python -m pip install 'numpy>=1.24,<3' 'opencv-python-headless>=4.8,<5' 'Pillow>=10,<13'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot install PerfectPixel dependencies.' }
}

$manifest = [ordered]@{
    repository = $config.repository
    revision = $config.revision
    archive_url = $config.url
    archive_sha256 = $actualHash
    source_directory = $sourceRoot
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $toolRoot 'source.json') -Encoding UTF8
& $python (Join-Path $PSScriptRoot 'perfect_pixel.py') --check
if ($LASTEXITCODE -ne 0) { throw 'PerfectPixel setup verification failed.' }
