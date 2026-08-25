Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$packageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
$godot = Get-ChildItem -LiteralPath $packageRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object Name -Like "GodotEngine.GodotEngine_*" |
    ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter "Godot*_console.exe" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $godot) {
	$portableGodot = Join-Path $projectRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
	if (Test-Path -LiteralPath $portableGodot) { $godot = Get-Item -LiteralPath $portableGodot }
}
if (-not $godot) { throw "Godot console executable not found." }
& $godot.FullName --path $projectRoot --script "res://tests/capture_lab.gd"
if ($LASTEXITCODE -ne 0) { throw "Preview capture failed" }
& $godot.FullName --path $projectRoot --script "res://tests/capture_cheems_vfx.gd"
if ($LASTEXITCODE -ne 0) { throw "Cheems VFX preview capture failed" }
& $godot.FullName --path $projectRoot --script "res://tests/capture_sword_shield_dog.gd"
if ($LASTEXITCODE -ne 0) { throw "Sword-and-shield dog preview capture failed" }
