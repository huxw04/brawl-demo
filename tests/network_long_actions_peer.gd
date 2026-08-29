extends SceneTree

var role := "client"
var port := 24637
var failures: Array[String] = []
var session: BrawlNetworkSession


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	_run.call_deferred()


func _run() -> void:
	session = root.get_node("NetworkSession") as BrawlNetworkSession
	if role == "host":
		await _run_host()
	else:
		await _run_client()
	if failures.is_empty():
		print("NETWORK_LONG_ACTIONS_%s_PASS" % role.to_upper())
		session.close_session()
		await process_frame
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		session.close_session()
		await process_frame
		quit(1)


func _run_host() -> void:
	_check(session.host_room("长动作房主", "cheems_samurai", port) == OK, "host should create the long-action room")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 2 and session.can_host_start(), 360), "host should receive the Chu Ying client")
	if session.can_host_start():
		session.host_start_match()
	_check(await _wait_for_match(), "host should enter the long-action match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(-0.5, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(-0.5, 0.05, 0.0)) < 0.35 and remote.global_position.distance_to(Vector3(0.5, 0.05, 0.0)) < 0.45, 720), "both actors should meet inside Cheems ultimate")
	own.energy = own.definition.max_energy
	var ultimate := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY)
	ultimate.ability_id = "ultimate"
	current_scene.command_gateway.submit(ultimate)
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_dimensional_focus") > 0, 180), "host should consume the reliable Cheems focus")
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_dimensional_circle") > 0, 180), "host should consume the reliable Cheems circle")
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_dimensional_cut") >= 4, 360), "host should consume all dimensional damage pulses")
	_check(await _wait_until(func() -> bool: return _effect_count("chu_ying_teleport_charge") > 0, 480), "host should receive Chu Ying's teleport charge")
	_check(await _wait_until(func() -> bool: return _effect_count("chu_ying_teleport") > 0, 180), "host should receive Chu Ying's resolved teleport endpoints")
	_check(await _wait_until(func() -> bool: return own.current_ability == null and own.hurt_remaining <= 0.0, 180), "Cheems should recover before the multi-slash test")
	var multi_slash := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, remote.global_position)
	multi_slash.ability_id = "skill_w"
	current_scene.command_gateway.submit(multi_slash)
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_multi_slash") > 0, 180), "host should consume one multi-slash start event")
	_check(await _wait_until(func() -> bool: return _history_type_count(remote.battle_id, BattleCommand.Type.STOP) >= 2, 360), "host should wait for client long-action assertions")
	session.close_session()


func _run_client() -> void:
	await _frames(20)
	_check(session.join_room("127.0.0.1", "褚赢客户端", "chu_ying", port) == OK, "client should join the long-action room")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 360), "client should receive the lobby")
	session.set_local_ready(true)
	_check(await _wait_for_match(), "client should enter the long-action match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(0.5, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(0.5, 0.05, 0.0)) < 0.45 and remote.global_position.distance_to(Vector3(-0.5, 0.05, 0.0)) < 0.45, 720), "client should observe the shared center setup")
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_dimensional_focus") > 0, 240), "client should receive Cheems focus")
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_dimensional_circle") > 0, 180), "client should receive Cheems magic circle")
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_dimensional_cut") >= 4, 360), "client should receive each dimensional pulse exactly through reliable events")
	_check(await _wait_until(func() -> bool: return remote.current_ability == null and own.current_ability == null and own.hurt_remaining <= 0.0, 300), "Cheems ultimate should finish before teleport input")
	var old_position := own.global_position
	var teleport := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, Vector3(2.5, 0.0, 0.0))
	teleport.ability_id = "skill_e"
	current_scene.command_gateway.submit(teleport)
	_check(await _wait_until(func() -> bool: return _effect_count("chu_ying_teleport_charge") > 0, 180), "client should receive its teleport charge event")
	_check(await _wait_until(func() -> bool: return _effect_count("chu_ying_teleport") > 0, 180), "client should receive both resolved teleport endpoints")
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(old_position) > 0.75, 180), "authoritative snapshot should move Chu Ying to the resolved endpoint")
	_check(await _wait_until(func() -> bool: return _effect_count("cheems_multi_slash") > 0, 240), "client should receive one reliable Cheems multi-slash start")
	_check(await _wait_until(func() -> bool: return current_scene.find_children("MultiSlashVisual", "MeshInstance3D", true, false).size() > 0, 120), "client should expand that start into local layered slash visuals")
	for _index in range(2):
		current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.STOP))
		await _frames(4)
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE, 360), "client should finish when host closes the focused test")


func _effect_count(vfx_id: String) -> int:
	return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get(vfx_id, 0))


func _wait_for_match() -> bool:
	if not await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 360):
		return false
	return await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == BrawlNetworkSession.MATCH_SCENE, 180)


func _history_type_count(actor_id: int, type: int) -> int:
	var count := 0
	for command in current_scene.command_stream.history:
		if command.actor_id == actor_id and command.type == type:
			count += 1
	return count


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _index in range(maximum_frames):
		if predicate.call():
			return true
		await process_frame
	return false


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[%s] %s" % [role, message])
