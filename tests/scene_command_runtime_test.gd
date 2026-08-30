extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var battle_scene := (load("res://scenes/battle_arena.tscn") as PackedScene).instantiate()
	root.add_child(battle_scene)
	await _frames(3)
	battle_scene.call("start_battle", "sword_shield_dog")
	await _frames(3)
	var battle_player := battle_scene.get("player") as CombatActor
	var battle_stream := battle_scene.get("command_stream") as BattleCommandStream
	var battle_runtime := battle_scene.get("command_runtime") as BattleCommandRuntime
	_check(battle_runtime != null and battle_runtime.running, "battle scene should use the shared command runtime")
	_check(is_zero_approx(battle_player.energy) and not battle_player.ignore_ability_requirements, "battle should start with real zero-resource rules")
	var accepted_results: Array[bool] = []
	battle_runtime.command_processed.connect(func(command: BattleCommand, accepted: bool) -> void:
		if command.actor_id == battle_player.battle_id and command.ability_id == "ultimate":
			accepted_results.append(accepted)
	)
	var battle_command := BattleCommand.create(battle_player.battle_id, BattleCommand.Type.CAST_ABILITY, battle_player.global_position)
	battle_command.ability_id = "ultimate"
	battle_stream.submit(battle_command)
	await _frames(50)
	_check(accepted_results == [true], "authoritative runtime should accept the sword-and-shield ultimate command")
	_check(battle_player.transformed, "sword-and-shield dog should transform from the real battle scene")
	battle_scene.queue_free()
	await _frames(3)

	var lab_scene := (load("res://scenes/character_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab_scene)
	await _frames(3)
	lab_scene.call("_spawn_lab_hero", "sword_shield_dog")
	await _frames(3)
	var bypass_check := lab_scene.get("bypass_check") as CheckButton
	bypass_check.button_pressed = false
	var lab_hero := lab_scene.get("hero") as CombatActor
	var lab_dummy := lab_scene.get("dummy") as CombatActor
	var lab_stream := lab_scene.get("command_stream") as BattleCommandStream
	var lab_runtime := lab_scene.get("command_runtime") as BattleCommandRuntime
	_check(is_equal_approx(lab_dummy.definition.max_hp, 250.0), "Lab dummy should use the readable 250-health test pool")
	lab_dummy.hp = 100.0
	await _frames(65)
	_check(is_equal_approx(lab_dummy.hp, 130.0), "an injured Lab dummy should regenerate 30 health once per second")
	var history_before := lab_stream.history.size()
	lab_scene.call("_submit_lab_ability", "ultimate")
	await _frames(50)
	_check(lab_runtime != null, "Lab should use the same shared command runtime class")
	_check(lab_stream.history.size() == history_before + 1, "Lab action button should submit a serializable battle command")
	_check(lab_stream.history[-1].type == BattleCommand.Type.CAST_ABILITY and lab_stream.history[-1].ability_id == "ultimate", "Lab R button should use the normal CAST_ABILITY command")
	_check(lab_hero.transformed, "Lab command path should produce the same transformation result")
	lab_scene.queue_free()
	await _frames(3)

	if failures.is_empty():
		print("Scene command runtime checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
