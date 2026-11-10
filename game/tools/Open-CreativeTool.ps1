param([ValidateSet('krita','audacity')][string]$Tool='krita')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$installed = Get-Content -LiteralPath (Join-Path $projectRoot '.tools\installed.json') -Raw | ConvertFrom-Json
$toolPath = $installed.$Tool
if (-not $toolPath -or -not (Test-Path -LiteralPath $toolPath)) {
    throw 'Creative tool is missing. Run tools\Install-Environment.ps1 without -SkipCreativeTools.'
}
& $toolPath
