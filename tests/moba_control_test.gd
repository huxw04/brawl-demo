extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(CheemsSamurai.create().ability_by_id("skill_q").targeting_preview == "line", "Cheems Q should use a line preview")
	_check(SwordShieldDog.create().ability_by_id("skill_w").targeting_preview == "box", "sword-and-shield W should use a box preview")
	var transformed_dash := SwordShieldDog.create().transformed_ability_by_id("skill_w")
	_check(not transformed_dash.requires_aim_confirmation and transformed_dash.face_move_direction_on_cast, "transformed dash should instantly use movement direction")
	_check(BearGryllsJungler.create().ability_by_id("ultimate").targeting_preview == "unit", "Bear R should use a unit-lock preview")
	_check(Nailoong.create().ability_by_id("skill_e").targeting_preview == "leap", "Nailoong E should preview its path and landing area")
	_check(ChuYing.create().ability_by_id("ultimate").targeting_preview == "barrier", "Chu Ying R should use its custom rectangle preview")
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
	await _physics_frames(2)
	_check(battle.move_indicator.marker != null, "right click should create a persistent resolved destination marker")
	if battle.move_indicator.marker != null:
		var marker_position: Vector3 = battle.move_indicator.marker.global_position
		_check(Vector2(marker_position.x, marker_position.z).distance_to(Vector2(destination.x, destination.z)) < 0.05, "destination marker should use the pathfinder's resolved endpoint")
	await _physics_frames(68)
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
	var history_before_q_release: int = battle.command_stream.history.size()
	var q_release := InputEventKey.new()
	q_release.keycode = KEY_Q
	q_release.pressed = false
	battle.player_controller._unhandled_input(q_release)
	await _physics_frames(2)
	_check(battle.command_stream.history.size() == history_before_q_release, "releasing an aimed skill key must not submit a stray END_ABILITY command")
	await _physics_frames(2)
	_check(battle.targeting_preview.shown_ability_id == "skill_q" and battle.targeting_preview.preview_mesh.get_surface_count() > 0, "armed directional ability should display world-space targeting geometry")
	_check(battle.targeting_preview.fill_material.albedo_color.a <= 0.05 and battle.targeting_preview.edge_material.albedo_color.a <= 0.25, "thicker targeting geometry should remain visually subtle through low overall opacity")
	_check(battle.targeting_preview.edge_material.cull_mode == BaseMaterial3D.CULL_DISABLED, "two-sided ground strips should not disappear because of triangle winding")
	var cast_click := InputEventMouseButton.new()
	cast_click.button_index = MOUSE_BUTTON_LEFT
	cast_click.pressed = true
	cast_click.position = battle.arena.camera.unproject_position(player.global_position + Vector3.RIGHT * 2.0)
	battle.player_controller._unhandled_input(cast_click)
	await _physics_frames(2)
	_check(float(player.cooldowns.get("skill_q", 0.0)) > 0.0, "left click should confirm the armed directional ability")

	player.reset_runtime(player.global_position)
	player.cooldowns["skill_q"] = 3.0
	battle.player_controller._unhandled_input(q_key)
	await _physics_frames(2)
	_check(battle.player_controller.pending_ability.is_empty(), "an ability on cooldown should not arm mouse targeting")
	_check(battle.targeting_preview.shown_ability_id.is_empty() and battle.targeting_preview.preview_mesh.get_surface_count() == 0, "cooldown rejection should leave no targeting geometry behind")

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
