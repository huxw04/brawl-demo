param(
    [string]$ExecutablePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not $ExecutablePath) {
    $ExecutablePath = Join-Path $projectRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
}
if (-not (Test-Path -LiteralPath $ExecutablePath)) { throw "Godot or exported game executable not found: $ExecutablePath" }
$arguments = @()
if ((Split-Path -Leaf $ExecutablePath) -like "Godot*") {
    $arguments = @("--path", $projectRoot)
}
Start-Process -FilePath $ExecutablePath -ArgumentList ($arguments + @("--position", "20,70")) -WorkingDirectory $projectRoot
Start-Process -FilePath $ExecutablePath -ArgumentList ($arguments + @("--position", "660,70")) -WorkingDirectory $projectRoot
Write-Host "Two game windows started. Create in one window and join 127.0.0.1 in the other."
