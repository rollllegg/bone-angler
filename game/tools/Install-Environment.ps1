#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SkipCreativeTools,
    [switch]$SkipExportTemplates,
    [switch]$SkipEditorExtension
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = Join-Path $projectRoot '.tools'
$downloadRoot = Join-Path $toolsRoot 'downloads'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $toolsRoot '.gdignore') -Value '' -Encoding ASCII
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-VerifiedDownload($Package) {
    $destination = Join-Path $downloadRoot $Package.file
    if (Test-Path -LiteralPath $destination) {
        $existingHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($existingHash -eq $Package.sha256) {
            Write-Output "Verified cache: $($Package.file)"
            return $destination
        }
    }
    Write-Host "Downloading official package: $($Package.file)"
    $partial = "$destination.part"
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe --location --fail --silent --show-error --retry 3 --connect-timeout 30 --output $partial $Package.url
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $($Package.file)" }
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri $Package.url -OutFile $partial
    }
    $downloadHash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
    if ($downloadHash -ne $Package.sha256) { throw "SHA-256 mismatch: $($Package.file)" }
    Move-Item -LiteralPath $partial -Destination $destination -Force
    return $destination
}

function Expand-Tool($Archive, $Destination) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    if ($Archive.EndsWith('.7z')) {
        $sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
        if (Test-Path -LiteralPath $sevenZip) {
            & $sevenZip x $Archive "-o$Destination" -y -bso0 -bsp0
        } else {
            & tar.exe -xf $Archive -C $Destination
        }
        if ($LASTEXITCODE -ne 0) { throw 'Archive extraction failed.' }
    } else {
        Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
    }
}

$godotArchive = Get-VerifiedDownload $manifest.godot | Select-Object -Last 1
$godotRoot = Join-Path $toolsRoot 'godot'
Expand-Tool $godotArchive $godotRoot
Set-Content -LiteralPath (Join-Path $godotRoot '_sc_') -Value '' -Encoding ASCII
$godotExe = Join-Path $godotRoot $manifest.godot.executable
if (-not (Test-Path -LiteralPath $godotExe)) { throw 'Godot executable not found after extraction.' }
$godotConsole = $godotExe -replace '\.exe$', '_console.exe'
if (-not (Test-Path -LiteralPath $godotConsole)) { $godotConsole = $godotExe }
& $godotConsole --version
if ($LASTEXITCODE -ne 0) { throw 'Godot version check failed.' }

$installed = [ordered]@{godot=$godotExe; godot_version=$manifest.godot.version; templates=$null; krita=$null; audacity=$null; vscode_extension=$null}
$installedPath = Join-Path $toolsRoot 'installed.json'
if (Test-Path -LiteralPath $installedPath) {
    $previous = Get-Content -LiteralPath $installedPath -Raw | ConvertFrom-Json
    foreach ($key in @('templates','krita','audacity','vscode_extension')) {
        if ($previous.$key) { $installed[$key] = $previous.$key }
    }
}

if (-not $SkipEditorExtension) {
    $extensionArchive = Get-VerifiedDownload $manifest.vscode_extension | Select-Object -Last 1
    $codeCommand = Get-Command code.cmd -ErrorAction SilentlyContinue
    if (-not $codeCommand) { $codeCommand = Get-Command code -ErrorAction SilentlyContinue }
    if ($codeCommand) {
        & $codeCommand.Source --install-extension $extensionArchive --force
        if ($LASTEXITCODE -ne 0) { throw 'VS Code extension installation failed.' }
        $installed.vscode_extension = $manifest.vscode_extension.version
    } else {
        Write-Warning 'VS Code was not found. Godot has a built-in script editor; install the cached VSIX after installing VS Code.'
    }
}

if (-not $SkipExportTemplates) {
    $templateArchive = Get-VerifiedDownload $manifest.templates | Select-Object -Last 1
    $templateRoot = Join-Path $godotRoot ('editor_data\export_templates\' + $manifest.godot.template_folder)
    New-Item -ItemType Directory -Path $templateRoot -Force | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($templateArchive)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.Name
            if ($name -eq 'version.txt' -or $name -match '^windows_.*x86_64.*\.exe$' -or $name -match '^web_.*\.zip$') {
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templateRoot $name), $true)
            }
        }
    } finally { $zip.Dispose() }
    $installed.templates = $templateRoot
    Write-Host 'Installed matching Windows x64 and Web export templates.'
}

if (-not $SkipCreativeTools) {
    $kritaArchive = Get-VerifiedDownload $manifest.krita | Select-Object -Last 1
    $kritaRoot = Join-Path $toolsRoot 'krita'
    Expand-Tool $kritaArchive $kritaRoot
    $kritaExe = Get-ChildItem -LiteralPath $kritaRoot -Recurse -Filter 'krita.exe' -File | Select-Object -First 1
    if (-not $kritaExe) { throw 'Krita executable not found.' }
    $installed.krita = $kritaExe.FullName

    $audacityArchive = Get-VerifiedDownload $manifest.audacity | Select-Object -Last 1
    $audacityRoot = Join-Path $toolsRoot 'audacity'
    $audacityVersionRoot = Join-Path $audacityRoot $manifest.audacity.version
    $audacityCanonicalExe = Join-Path $audacityVersionRoot 'bin\Audacity4.exe'
    if (-not (Test-Path -LiteralPath $audacityCanonicalExe)) {
        Expand-Tool $audacityArchive $audacityRoot
        $unpackedExe = Get-ChildItem -LiteralPath $audacityRoot -Recurse -Filter 'Audacity4.exe' -File | Select-Object -First 1
        if (-not $unpackedExe) { throw 'Audacity executable not found.' }
        $unpackedBundle = Split-Path -Parent $unpackedExe.DirectoryName
        $audacityBoundary = [IO.Path]::GetFullPath($audacityRoot).TrimEnd('\') + '\'
        foreach ($pathToCheck in @($unpackedBundle, $audacityVersionRoot)) {
            if (-not [IO.Path]::GetFullPath($pathToCheck).StartsWith($audacityBoundary, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Audacity extraction path is outside the expected tool directory.'
            }
        }
        Move-Item -LiteralPath $unpackedBundle -Destination $audacityVersionRoot
    }
    $audacityExe = Get-Item -LiteralPath $audacityCanonicalExe -ErrorAction SilentlyContinue
    if (-not $audacityExe) { throw 'Audacity executable not found.' }
    New-Item -ItemType Directory -Path (Join-Path $audacityExe.DirectoryName 'Portable Settings') -Force | Out-Null
    $installed.audacity = $audacityExe.FullName
}

$settingsPath = Join-Path $projectRoot '.vscode\settings.json'
New-Item -ItemType Directory -Path (Split-Path -Parent $settingsPath) -Force | Out-Null
$settings = @{}
if (Test-Path -LiteralPath $settingsPath) {
    $currentSettings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    foreach ($property in $currentSettings.PSObject.Properties) { $settings[$property.Name] = $property.Value }
}
$settings['godotTools.editorPath.godot4'] = $godotExe.Replace('\','/')
$settings['godotTools.lsp.headless'] = $true
$gdscriptSettings = @{}
if ($settings.ContainsKey('[gdscript]')) {
    foreach ($property in $settings['[gdscript]'].PSObject.Properties) { $gdscriptSettings[$property.Name] = $property.Value }
}
$gdscriptSettings['editor.defaultFormatter'] = 'geequlim.godot-tools'
$gdscriptSettings['editor.insertSpaces'] = $false
$gdscriptSettings['editor.tabSize'] = 4
$settings['[gdscript]'] = $gdscriptSettings
$settingsJson = $settings | ConvertTo-Json -Depth 8
$settingsJson | ConvertFrom-Json | Out-Null
[IO.File]::WriteAllText($settingsPath, $settingsJson + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $toolsRoot 'installed.json'), ($installed | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
Write-Host 'Development tools are ready. Run tools\Check-Environment.ps1 to verify the project.'
