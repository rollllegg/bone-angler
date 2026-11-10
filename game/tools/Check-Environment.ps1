. (Join-Path $PSScriptRoot 'Common.ps1')
$godot = Get-GodotPath -Console
$version = (& $godot --version | Out-String).Trim()
if (-not $version.StartsWith($script:Toolchain.godot.version + '.stable')) {
    throw "Unexpected Godot version: $version"
}
Write-Host "Godot version: $version"
Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--editor','--quit')
Invoke-GodotChecked -GodotArguments @('--headless','--path',$script:ProjectRoot,'--quit-after','5')
$templateRoot = Join-Path (Split-Path -Parent $godot) ('editor_data\export_templates\' + $script:Toolchain.godot.template_folder)
foreach ($template in @('windows_release_x86_64.exe','windows_debug_x86_64.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $templateRoot $template))) { throw "Missing export template: $template" }
}
if (-not (Get-ChildItem -LiteralPath $templateRoot -Filter 'web*release*.zip')) { throw 'Missing Web export templates.' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is missing.' }
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python is missing (used for local Web preview).' }
git --version
git lfs version
Write-Host 'PASS: editor import, startup scene, export templates and development commands.'
