extends SceneTree

const ImpairmentProxyScript = preload("res://tests/network_impairment_proxy.gd")

var role := "client"
var port := 24647
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
		print("NETWORK_IMPAIRMENT_%s_PASS" % role.to_upper())
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
	_check(session.host_room("劣化测试房主", "cheems_samurai", port) == OK, "host should create the impairment room")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 2 and session.can_host_start(), 360), "host should receive the client")
	if session.can_host_start():
		session.host_start_match()
	_check(await _wait_for_match(), "host should enter the match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	var waypoints := [
		Vector3(-2.4, 0.0, -1.2), Vector3(-0.8, 0.0, 1.3),
		Vector3(-2.2, 0.0, 1.0), Vector3(-0.6, 0.0, -1.1),
		Vector3(-1.8, 0.0, 0.8), Vector3(-1.0, 0.0, 0.0),
	]
	for index in range(waypoints.size()):
		current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, waypoints[index]))
		if index == 1:
			var q := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, remote.global_position)
			q.ability_id = "skill_q"
			current_scene.command_gateway.submit(q)
		await _frames(75)
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(-1.0, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(-1.0, 0.05, 0.0)) < 0.45, 360), "host should finish at its convergence point")
	_check(await _wait_until(func() -> bool: return _history_type_count(remote.battle_id, BattleCommand.Type.STOP) >= 2, 480), "host should receive the client's completion commands")
	_check(remote.global_position.distance_to(Vector3(1.0, 0.05, 0.0)) < 0.55, "authority should finish the client at its convergence point")
	session.close_session()


func _run_client() -> void:
	await _frames(20)
	_check(session.join_room("127.0.0.1", "劣化测试客户端", "nailoong", port) == OK, "client should join the impairment room")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 360), "client should receive the lobby")
	session.set_local_ready(true)
	_check(await _wait_for_match(), "client should enter the match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	var proxy := ImpairmentProxyScript.new() as NetworkImpairmentProxy
	current_scene.add_child(proxy)
	proxy.setup(session, current_scene)
	var waypoints := [
		Vector3(2.4, 0.0, 1.2), Vector3(0.8, 0.0, -1.3),
		Vector3(2.2, 0.0, -1.0), Vector3(0.6, 0.0, 1.1),
		Vector3(1.8, 0.0, -0.8), Vector3(1.0, 0.0, 0.0),
	]
	for index in range(waypoints.size()):
		current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, waypoints[index]))
		if index == 2:
			var roll := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, waypoints[index])
			roll.ability_id = "skill_q"
			current_scene.command_gateway.submit(roll)
		await _frames(75)
	_check(proxy.actor_received > 40 and proxy.entity_received > 20, "the sustained test should intercept live snapshot traffic")
	_check(proxy.actor_dropped > 0 and proxy.entity_dropped > 0, "the proxy should drop actor and entity snapshots")
	_check(proxy.actor_delivered > 0 and proxy.entity_delivered > 0, "the client should continue applying surviving snapshots")
	_check(proxy.actor_duplicated > 0 and proxy.entity_duplicated > 0, "the proxy should retain delayed snapshot copies to force reordering")
	_check(proxy.maximum_queue_depth >= 4, "jitter should build a non-trivial receive queue")
	_check(current_scene.match_replica.stale_actor_snapshot_count > 0, "late actor snapshots should be rejected by authority tick")
	_check(current_scene.match_replica.stale_entity_snapshot_count > 0, "late entity snapshots should be rejected by authority tick")
	_check(proxy.event_received > 0 and proxy.event_duplicated > 0, "reliable combat events should be delayed and duplicated")
	_check(current_scene.match_replica.stale_authoritative_event_count > 0, "duplicate reliable events should be idempotently rejected")
	proxy.restore_direct_delivery()
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.CANCEL_ABILITY))
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(1.0, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(1.0, 0.05, 0.0)) < 0.45, 360), "client should converge after direct delivery is restored")
	_check(await _wait_until(func() -> bool: return remote.global_position.distance_to(Vector3(-1.0, 0.05, 0.0)) < 0.5, 360), "remote authority actor should also converge after recovery")
	_check(current_scene.find_children("*", "CombatProjectile", true, false).is_empty(), "impaired client must not create authoritative simulation projectiles")
	for _index in range(2):
		current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.STOP))
		await _frames(4)
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE, 480), "client should finish when host closes the test")


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
