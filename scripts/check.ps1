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
    "res://scenes/battle_arena.tscn",
    "res://scenes/network_lobby.tscn",
    "res://scenes/network_match.tscn"
)
foreach ($scene in $scenes) {
    Write-Host "Smoke test: $scene"
    & $godotPath --headless --path $projectRoot --quit-after 12 $scene
    if ($LASTEXITCODE -ne 0) { throw "Scene smoke test failed: $scene" }
}

$integrationTests = @(
	@{ Label = "data-driven maps and dynamic navigation"; Script = "res://tests/map_definition_test.gd" },
	@{ Label = "authority respawn and safe spawn selection"; Script = "res://tests/respawn_manager_test.gd" },
	@{ Label = "match score, assists, streaks, and results"; Script = "res://tests/score_manager_test.gd" },
	@{ Label = "local combat feedback and floating numbers"; Script = "res://tests/combat_feedback_test.gd" },
    @{ Label = "combat rules"; Script = "res://tests/combat_integration.gd" },
    @{ Label = "commands, RNG, and pathfinding"; Script = "res://tests/command_system_test.gd" },
	@{ Label = "authority events and stable entity ids"; Script = "res://tests/authority_runtime_test.gd" },
	@{ Label = "read-only match replica"; Script = "res://tests/match_replica_test.gd" },
	@{ Label = "network fault injection and recovery"; Script = "res://tests/network_fault_injection_test.gd" },
	@{ Label = "continuous ability authority sessions"; Script = "res://tests/continuous_ability_session_test.gd" },
    @{ Label = "shared Lab and battle command runtime"; Script = "res://tests/scene_command_runtime_test.gd" },
    @{ Label = "MOBA input and state digest"; Script = "res://tests/moba_control_test.gd" },
    @{ Label = "Cheems samurai"; Script = "res://tests/cheems_samurai_test.gd" },
    @{ Label = "sword-and-shield dog"; Script = "res://tests/sword_shield_dog_test.gd" },
    @{ Label = "Bear Grylls skills"; Script = "res://tests/bear_grylls_skill_test.gd" },
    @{ Label = "Bear Grylls walk animation"; Script = "res://tests/bear_grylls_walk_test.gd" },
    @{ Label = "Nailoong"; Script = "res://tests/nailoong_test.gd" },
    @{ Label = "Chu Ying"; Script = "res://tests/chu_ying_test.gd" },
    @{ Label = "safe scene navigation"; Script = "res://tests/scene_navigation_test.gd" }
)
foreach ($test in $integrationTests) {
    Write-Host "Integration test: $($test.Label)"
    & $godotPath --headless --path $projectRoot --script $test.Script
    if ($LASTEXITCODE -ne 0) { throw "Integration test failed: $($test.Script)" }
}

Write-Host "Integration test: Stage C localhost host/client combat"
& (Join-Path $PSScriptRoot "test_network_stage_a.ps1") -GodotPath $godotPath
if ($LASTEXITCODE -ne 0) { throw "Stage C network test failed" }

Write-Host "Integration test: Stage C world-anchored entities"
& (Join-Path $PSScriptRoot "test_network_stage_a.ps1") -GodotPath $godotPath -PeerScript "res://tests/network_world_entities_peer.gd" -Port 24617 -HostMarker "NETWORK_WORLD_ENTITIES_HOST_PASS" -ClientMarker "NETWORK_WORLD_ENTITIES_CLIENT_PASS" -Label "Stage C world-entity localhost" -TimeoutMs 30000
if ($LASTEXITCODE -ne 0) { throw "Stage C world-entity network test failed" }

Write-Host "Integration test: Stage C reliable hero effects"
& (Join-Path $PSScriptRoot "test_network_stage_a.ps1") -GodotPath $godotPath -PeerScript "res://tests/network_hero_effects_peer.gd" -Port 24627 -HostMarker "NETWORK_HERO_EFFECTS_HOST_PASS" -ClientMarker "NETWORK_HERO_EFFECTS_CLIENT_PASS" -Label "Stage C reliable hero-effect localhost" -TimeoutMs 30000
if ($LASTEXITCODE -ne 0) { throw "Stage C hero-effect network test failed" }

Write-Host "Integration test: Stage C synchronized long actions"
& (Join-Path $PSScriptRoot "test_network_stage_a.ps1") -GodotPath $godotPath -PeerScript "res://tests/network_long_actions_peer.gd" -Port 24637 -HostMarker "NETWORK_LONG_ACTIONS_HOST_PASS" -ClientMarker "NETWORK_LONG_ACTIONS_CLIENT_PASS" -Label "Stage C synchronized long-action localhost" -TimeoutMs 30000
if ($LASTEXITCODE -ne 0) { throw "Stage C long-action network test failed" }

Write-Host "Integration test: Stage C sustained impaired transport"
& (Join-Path $PSScriptRoot "test_network_stage_a.ps1") -GodotPath $godotPath -PeerScript "res://tests/network_impairment_peer.gd" -Port 24647 -HostMarker "NETWORK_IMPAIRMENT_HOST_PASS" -ClientMarker "NETWORK_IMPAIRMENT_CLIENT_PASS" -Label "Stage C sustained impaired transport" -TimeoutMs 40000
if ($LASTEXITCODE -ne 0) { throw "Stage C impaired transport network test failed" }

Write-Host "Integration test: Stage E authoritative respawn"
& (Join-Path $PSScriptRoot "test_network_stage_a.ps1") -GodotPath $godotPath -PeerScript "res://tests/network_respawn_peer.gd" -Port 24657 -HostMarker "NETWORK_RESPAWN_HOST_PASS" -ClientMarker "NETWORK_RESPAWN_CLIENT_PASS" -Label "Stage E authoritative respawn" -TimeoutMs 30000
if ($LASTEXITCODE -ne 0) { throw "Stage E respawn network test failed" }

Write-Host "Integration test: Stage E synchronized score and results"
& (Join-Path $PSScriptRoot "test_network_stage_a.ps1") -GodotPath $godotPath -PeerScript "res://tests/network_match_rules_peer.gd" -Port 24667 -HostMarker "NETWORK_MATCH_RULES_HOST_PASS" -ClientMarker "NETWORK_MATCH_RULES_CLIENT_PASS" -Label "Stage E synchronized score and results" -TimeoutMs 30000
if ($LASTEXITCODE -ne 0) { throw "Stage E match-rules network test failed" }

Write-Host "Integration test: four-player localhost capacity"
& (Join-Path $PSScriptRoot "test_network_four_players.ps1") -GodotPath $godotPath -Port 24677 -TimeoutMs 45000
if ($LASTEXITCODE -ne 0) { throw "Four-player capacity test failed" }
