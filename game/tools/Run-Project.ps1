param([switch]$Headless, [int]$QuitAfter=0)
. (Join-Path $PSScriptRoot 'Common.ps1')
$arguments = @('--path', $script:ProjectRoot)
if ($Headless) { $arguments += '--headless' }
if ($QuitAfter -gt 0) { $arguments += @('--quit-after', "$QuitAfter") }
Invoke-GodotChecked -GodotArguments $arguments
