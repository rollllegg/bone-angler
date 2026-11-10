. (Join-Path $PSScriptRoot 'Common.ps1')
$godot = Get-GodotPath
& $godot --editor --path $script:ProjectRoot --language zh_CN
