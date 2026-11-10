$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:Toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json

function Get-GodotPath {
    param([switch]$Console)
    $godotPath = Join-Path $script:ProjectRoot ('.tools\godot\' + $script:Toolchain.godot.executable)
    if (-not (Test-Path -LiteralPath $godotPath)) {
        throw 'Godot is missing. Run tools\Install-Environment.ps1 first.'
    }
    if ($Console) {
        $consolePath = $godotPath -replace '\.exe$', '_console.exe'
        if (Test-Path -LiteralPath $consolePath) { return $consolePath }
    }
    return $godotPath
}

function Invoke-GodotChecked {
    param([Parameter(Mandatory=$true)][string[]]$GodotArguments)
    $godot = Get-GodotPath -Console
    $output = & $godot @GodotArguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0 -or ($output -match 'SCRIPT ERROR:|Parse Error:|^ERROR:')) {
        throw "Godot command failed (exit $exitCode)."
    }
}
