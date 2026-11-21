param([ValidateSet('Windows','Web','All')][string]$Target='All')
. (Join-Path $PSScriptRoot 'Common.ps1')

function Copy-FontLicenses {
    param([string]$Destination)
    $fonts = Join-Path $script:ProjectRoot 'assets\fonts'
    Copy-Item -LiteralPath (Join-Path $fonts 'OFL-NotoSansSC.txt') -Destination $Destination -Force
    $fusionLicenses = Join-Path $Destination 'licenses\fusion-pixel'
    New-Item -ItemType Directory -Path $fusionLicenses -Force | Out-Null
    Copy-Item -LiteralPath @(
        (Join-Path $fonts 'fusion-pixel\OFL.txt'),
        (Join-Path $fonts 'fusion-pixel\LICENSES')
    ) -Destination $fusionLicenses -Recurse -Force
}

$buildRoot = Join-Path $script:ProjectRoot 'build'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $buildRoot '.gdignore') -Value '' -Encoding ASCII
Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--editor','--quit')
if ($Target -in @('Windows','All')) {
    $destination = Join-Path $script:ProjectRoot 'build\windows'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--export-release','Windows Desktop',(Join-Path $destination 'BoneFishing.exe'))
    Copy-FontLicenses -Destination $destination
    Write-Host "Windows build: $destination"
}
if ($Target -in @('Web','All')) {
    $destination = Join-Path $script:ProjectRoot 'build\web'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--export-release','Web',(Join-Path $destination 'index.html'))
    Copy-FontLicenses -Destination $destination
    Write-Host "Web build: $destination"
}
