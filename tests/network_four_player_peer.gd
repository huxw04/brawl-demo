extends SceneTree

var role := "client"
var client_index := 1
var port := 24677
var failures: Array[String] = []
var session: BrawlNetworkSession

const HEROES := ["cheems_samurai", "nailoong", "sword_shield_dog", "bear_grylls_jungler"]


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--client-index="):
			client_index = int(argument.trim_prefix("--client-index="))
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	_run.call_deferred()


func _run() -> void:
	session = root.get_node("NetworkSession") as BrawlNetworkSession
	if role == "host":
		await _run_host()
	elif client_index == 4:
		await _run_overflow_client()
	else:
		await _run_client()
	if failures.is_empty():
		var marker_role := "HOST" if role == "host" else "CLIENT%d" % client_index
		print("NETWORK_FOUR_PLAYER_%s_PASS" % marker_role)
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
	_check(session.host_room("四人房主", HEROES[0], port) == OK, "host should create a four-player room")
	session.request_map_selection(BrawlMapCatalog.WIND_GORGE_MAP_ID)
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 4 and session.can_host_start(), 600), "host should receive three distinct ready clients")
	if session.can_host_start():
		_check(session.host_start_match(), "host should start a four-player match")
	_check(await _wait_for_match(), "host should enter the synchronized match")
	_check(str(session.match_config.get("map_id", "")) == BrawlMapCatalog.WIND_GORGE_MAP_ID, "host should start the room-selected map")
	for snapshot in current_scene._build_state_snapshots():
		_check(var_to_bytes(snapshot).size() < 1392, "each unreliable actor snapshot should remain below the ENet MTU")
	_check(_validate_four_player_scene(), "host should create four unique authoritative actors")
	await _submit_and_verify_own_move(0)
	_check(await _wait_until(_all_participants_completed, 900), "host should receive one owned MOVE_TO and completion STOP from every player")
	_check(await _wait_until(func() -> bool: return session.players.size() == 3, 480), "one ordinary client should be able to leave without ending the match")
	_check(await _wait_until(func() -> bool: return current_scene.actors_by_peer.size() == 3, 240), "departed client's actor should be removed while the other three continue")
	await _frames(30)


func _run_client() -> void:
	await _frames(15 + client_index * 8)
	var hero_id: String = HEROES[clampi(client_index, 1, HEROES.size() - 1)]
	_check(session.join_room("127.0.0.1", "四人客户端%d" % client_index, hero_id, port) == OK, "client should begin joining the four-player room")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 480), "client should complete the room handshake")
	_check(session.selected_map_id == BrawlMapCatalog.WIND_GORGE_MAP_ID, "client should receive the host's selected map in lobby state")
	if client_index == 3:
		# Leave a deterministic lobby window for the fifth process to connect and
		# receive the application-level full-room rejection.
		await _frames(75)
	session.set_local_ready(true)
	_check(await _wait_for_match(), "client should enter the synchronized match")
	_check(str(session.match_config.get("map_id", "")) == BrawlMapCatalog.WIND_GORGE_MAP_ID, "client should load the room-selected map")
	_check(await _wait_until(_validate_four_player_scene, 240), "client should create four unique read-only actors and receive the initial scoreboard state")
	await _submit_and_verify_own_move(client_index)
	if client_index == 3:
		await _frames(75)
		session.close_session("capacity test client left")
		return
	_check(await _wait_until(func() -> bool: return session.players.size() == 3, 480), "remaining client should receive the departed peer's roster update")
	_check(await _wait_until(func() -> bool: return current_scene.actors_by_peer.size() == 3, 240), "remaining client should remove only the departed actor")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE, 480), "remaining client should leave safely when the host closes")


func _run_overflow_client() -> void:
	await _frames(45)
	_check(session.join_room("127.0.0.1", "第五位测试", "chu_ying", port) == OK, "overflow client should reach the transport handshake")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE and "房间已满" in session.last_error, 480), "the fifth process should receive an explicit full-room message")


func _submit_and_verify_own_move(index: int) -> void:
	var actor := current_scene.local_actor as CombatActor
	var start := actor.global_position
	var directions: Array[Vector3] = [Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, -1.4), Vector3(1.4, 0.0, 0.0), Vector3(-1.4, 0.0, 0.0)]
	var direction: Vector3 = directions[index]
	var command := BattleCommand.create(actor.battle_id, BattleCommand.Type.MOVE_TO, start + direction)
	current_scene.command_gateway.submit(command)
	_check(await _wait_until(func() -> bool: return actor.global_position.distance_to(start) > 0.65, 420), "owned movement should advance only the local actor")
	current_scene.command_gateway.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.STOP))


func _validate_four_player_scene() -> bool:
	var participants := session.match_config.get("participants", []) as Array
	if participants.size() != 4 or current_scene.actors_by_peer.size() != 4 or current_scene.actors_by_id.size() != 4:
		return false
	var actor_ids: Dictionary = {}
	var peer_ids: Dictionary = {}
	for participant_value in participants:
		var participant := participant_value as Dictionary
		actor_ids[int(participant.get("actor_id", 0))] = true
		peer_ids[int(participant.get("peer_id", 0))] = true
	if actor_ids.size() != 4 or peer_ids.size() != 4:
		return false
	if current_scene.scoreboard.current_state.get("stats", []).size() != 4:
		return false
	return current_scene.match_authority != null if role == "host" else current_scene.match_replica != null


func _all_participants_completed() -> bool:
	var completed: Dictionary = {}
	var moved: Dictionary = {}
	for command in current_scene.command_stream.history:
		if command.type == BattleCommand.Type.MOVE_TO:
			moved[command.actor_id] = true
		elif command.type == BattleCommand.Type.STOP:
			completed[command.actor_id] = true
	return moved.size() == 4 and completed.size() == 4


func _wait_for_match() -> bool:
	if not await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 600):
		return false
	return await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == BrawlNetworkSession.MATCH_SCENE, 240)


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
		failures.append(message)
