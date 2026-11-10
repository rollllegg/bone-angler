param([ValidateSet('Windows','Web','All')][string]$Target='All')
. (Join-Path $PSScriptRoot 'Common.ps1')
$buildRoot = Join-Path $script:ProjectRoot 'build'
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $buildRoot '.gdignore') -Value '' -Encoding ASCII
Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--editor','--quit')
if ($Target -in @('Windows','All')) {
    $destination = Join-Path $script:ProjectRoot 'build\windows'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--export-release','Windows Desktop',(Join-Path $destination 'BoneFishing.exe'))
    Copy-Item -LiteralPath (Join-Path $script:ProjectRoot 'assets\fonts\OFL-NotoSansSC.txt') -Destination (Join-Path $destination 'OFL-NotoSansSC.txt') -Force
    Write-Host "Windows build: $destination"
}
if ($Target -in @('Web','All')) {
    $destination = Join-Path $script:ProjectRoot 'build\web'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--export-release','Web',(Join-Path $destination 'index.html'))
    Copy-Item -LiteralPath (Join-Path $script:ProjectRoot 'assets\fonts\OFL-NotoSansSC.txt') -Destination (Join-Path $destination 'OFL-NotoSansSC.txt') -Force
    Write-Host "Web build: $destination"
}
