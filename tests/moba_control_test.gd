extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/battle_arena.tscn")
	var battle: Node3D = packed.instantiate()
	root.add_child(battle)
	battle.start_battle("cheems_samurai")
	await _physics_frames(10)
	battle.bot_controller.process_mode = Node.PROCESS_MODE_DISABLED
	var player: CombatActor = battle.player
	var start := player.global_position
	var destination := Vector3(-3.0, 0.0, 2.8)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = battle.arena.camera.unproject_position(destination)
	battle.player_controller._unhandled_input(click)
	await _physics_frames(70)
	_check(player.global_position.distance_to(destination) < start.distance_to(destination), "right click should move the player along an A* path")
	_check(battle.command_stream.history[0].type == BattleCommand.Type.MOVE_TO, "right click should record a MOVE_TO command")

	var command_count_before_ctrl: int = battle.command_stream.history.size()
	var ctrl_down := InputEventKey.new()
	ctrl_down.keycode = KEY_CTRL
	ctrl_down.pressed = true
	battle.player_controller._unhandled_input(ctrl_down)
	await _physics_frames(2)
	_check(battle.command_stream.history.size() == command_count_before_ctrl, "Ctrl should no longer submit a sprint command")

	var q_key := InputEventKey.new()
	q_key.keycode = KEY_Q
	q_key.pressed = true
	battle.player_controller._unhandled_input(q_key)
	_check(battle.player_controller.pending_ability == "skill_q", "Q should arm the Q ability")
	var cast_click := InputEventMouseButton.new()
	cast_click.button_index = MOUSE_BUTTON_LEFT
	cast_click.pressed = true
	cast_click.position = battle.arena.camera.unproject_position(player.global_position + Vector3.RIGHT * 2.0)
	battle.player_controller._unhandled_input(cast_click)
	await _physics_frames(2)
	_check(float(player.cooldowns.get("skill_q", 0.0)) > 0.0, "left click should confirm the armed directional ability")

	player.reset_runtime(player.global_position)
	player.energy = player.definition.max_energy
	var r_key := InputEventKey.new()
	r_key.keycode = KEY_R
	r_key.pressed = true
	battle.player_controller._unhandled_input(r_key)
	_check(battle.player_controller.pending_ability.is_empty(), "non-directional R should not enter mouse targeting")
	await _physics_frames(2)
	_check(float(player.cooldowns.get("ultimate", 0.0)) > 0.0, "R should cast immediately through the command stream")

	var digest_before: String = battle.current_state_checksum()
	var digest_repeat: String = battle.current_state_checksum()
	_check(digest_before == digest_repeat, "unchanged battle state should have a stable checksum")
	player.energy += 1.0
	_check(digest_before != battle.current_state_checksum(), "state checksum should detect authoritative resource changes")

	battle.queue_free()
	if failures.is_empty():
		print("MOBA input and state digest checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
