Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$command = Get-Command godot_console -ErrorAction SilentlyContinue
if (-not $command) { $command = Get-Command godot -ErrorAction SilentlyContinue }
if (-not $command) {
	$portableGodot = Join-Path $projectRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
	if (Test-Path -LiteralPath $portableGodot) { $command = Get-Item -LiteralPath $portableGodot }
}
if (-not $command) {
    $packageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $command = Get-ChildItem -LiteralPath $packageRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -Like "GodotEngine.GodotEngine_*" |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter "Godot*_console.exe" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}
if (-not $command) { throw "Godot 4 not found. Install GodotEngine.GodotEngine with winget." }
$godotPath = if ($command -is [System.IO.FileInfo]) { $command.FullName } else { $command.Source }
Write-Host "Godot: $godotPath"
& $godotPath --version
& $godotPath --headless --path $projectRoot --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot project validation failed with exit code $LASTEXITCODE" }

$scenes = @(
    "res://scenes/launcher.tscn",
    "res://scenes/character_lab.tscn",
    "res://scenes/battle_arena.tscn"
)
foreach ($scene in $scenes) {
    Write-Host "Smoke test: $scene"
    & $godotPath --headless --path $projectRoot --quit-after 12 $scene
    if ($LASTEXITCODE -ne 0) { throw "Scene smoke test failed: $scene" }
}

Write-Host "Integration test: combat rules"
& $godotPath --headless --path $projectRoot --script "res://tests/combat_integration.gd"
if ($LASTEXITCODE -ne 0) { throw "Combat integration test failed" }

Write-Host "Integration test: commands, RNG, and pathfinding"
& $godotPath --headless --path $projectRoot --script "res://tests/command_system_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Command system test failed" }

Write-Host "Integration test: Cheems samurai"
& $godotPath --headless --path $projectRoot --script "res://tests/cheems_samurai_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Cheems samurai test failed" }

Write-Host "Integration test: MOBA input and state digest"
& $godotPath --headless --path $projectRoot --script "res://tests/moba_control_test.gd"
if ($LASTEXITCODE -ne 0) { throw "MOBA control test failed" }

Write-Host "Integration test: sword-and-shield dog"
& $godotPath --headless --path $projectRoot --script "res://tests/sword_shield_dog_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Sword-and-shield dog test failed" }

Write-Host "Integration test: Bear Grylls jungler"
& $godotPath --headless --path $projectRoot --script "res://tests/bear_grylls_skill_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Bear Grylls skill test failed" }

Write-Host "Integration test: Nailoong"
& $godotPath --headless --path $projectRoot --script "res://tests/nailoong_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Nailoong test failed" }

Write-Host "Integration test: Chu Ying"
& $godotPath --headless --path $projectRoot --script "res://tests/chu_ying_test.gd"
if ($LASTEXITCODE -ne 0) { throw "Chu Ying test failed" }
