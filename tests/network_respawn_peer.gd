extends SceneTree

var role := "client"
var port := 24657
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
		print("NETWORK_RESPAWN_%s_PASS" % role.to_upper())
		session.close_session()
		await process_frame
		quit(0)
	else:
		for failure in failures:
			push_error("[%s] %s" % [role, failure])
		session.close_session()
		await process_frame
		quit(1)


func _run_host() -> void:
	_check(session.host_room("复活房主", "cheems_samurai", port) == OK, "host should create the room")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 2 and session.can_host_start(), 360), "host should receive a ready client")
	if session.can_host_start():
		session.host_start_match()
	_check(await _wait_for_match(), "host should enter the match")
	var client_actor := _remote_actor()
	_check(client_actor != null, "host should resolve the client actor")
	if client_actor != null:
		client_actor.call("_mark_defeated")
		_check(client_actor.is_defeated and client_actor.respawn_remaining > 2.8, "host should schedule the client's three-second countdown")
		_check(await _wait_until_msec(func() -> bool: return not client_actor.is_defeated, 6000), "host should respawn the client")
		_check(client_actor.spawn_protection_remaining > 1.0, "host should apply spawn protection")
		_check(_is_stable_spawn(client_actor.global_position), "host should choose a stable map spawn")
	_check(await _wait_until_msec(func() -> bool: return _remote_stop_count() > 0, 8000), "host should wait for the client's synchronized completion acknowledgement")
	session.close_session()


func _run_client() -> void:
	await _frames(20)
	_check(session.join_room("127.0.0.1", "复活客户端", "nailoong", port) == OK, "client should join the room")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 360), "client should receive the lobby")
	session.set_local_ready(true)
	_check(await _wait_for_match(), "client should enter the match")
	var actor := current_scene.local_actor as CombatActor
	_check(await _wait_until(func() -> bool: return actor.is_defeated and actor.respawn_remaining > 0.0, 180), "client should receive the defeated state and countdown")
	_check(await _wait_until_msec(func() -> bool: return not actor.is_defeated and actor.spawn_protection_remaining > 0.0, 6000), "client should receive the authoritative respawn and protection")
	_check(int(current_scene.authority_presentation.match_rule_counts_by_kind.get("respawn_scheduled", 0)) == 1, "client should consume one reliable schedule event")
	_check(int(current_scene.authority_presentation.match_rule_counts_by_kind.get("actor_respawned", 0)) == 1, "client should consume one reliable completion event")
	_check(current_scene.hud.respawn_mode_enabled and await _wait_until(func() -> bool: return not current_scene.hud.message_label.text.begins_with("阵亡"), 60), "client HUD should leave the death countdown after revival")
	current_scene.command_gateway.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.STOP))
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE, 360), "client should finish when the host closes")


func _wait_for_match() -> bool:
	if not await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 360):
		return false
	return await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == BrawlNetworkSession.MATCH_SCENE, 180)


func _remote_actor() -> CombatActor:
	for peer_id_value in current_scene.actors_by_peer.keys():
		if int(peer_id_value) != BrawlNetworkSession.SERVER_PEER_ID:
			return current_scene.actors_by_peer[peer_id_value] as CombatActor
	return null


func _remote_stop_count() -> int:
	var remote := _remote_actor()
	if remote == null:
		return 0
	var count := 0
	for command in current_scene.command_stream.history:
		if command.actor_id == remote.battle_id and command.type == BattleCommand.Type.STOP:
			count += 1
	return count


func _is_stable_spawn(position: Vector3) -> bool:
	for spawn in current_scene.arena.map_definition.spawn_points:
		var stable := spawn.get("position", Vector3.ZERO) as Vector3
		if Vector2(stable.x - position.x, stable.z - position.z).length() < 0.01:
			return true
	return false


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _index in range(maximum_frames):
		if predicate.call():
			return true
		await process_frame
	return false


func _wait_until_msec(predicate: Callable, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
