extends SceneTree

var role := "client"
var port := 24667
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
		print("NETWORK_MATCH_RULES_%s_PASS" % role.to_upper())
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
	_check(session.host_room("计分房主", "cheems_samurai", port) == OK, "host should create the room")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 2 and session.can_host_start(), 360), "host should receive a ready client")
	if session.can_host_start():
		session.host_start_match()
	_check(await _wait_for_match(), "host should enter the match")
	current_scene.score_manager.kill_limit = 1
	var victim := _remote_actor()
	var killer := current_scene.local_actor as CombatActor
	_check(victim != null, "host should resolve the remote victim")
	if victim != null:
		victim.receive_hit(killer, killer.ability_by_id("basic"), Vector3.RIGHT, 1, 9999.0)
	_check(await _wait_until(func() -> bool: return current_scene.score_manager.ended, 120), "kill limit should end the authority match")
	_check(not current_scene.command_gateway.accepting_commands and not current_scene.match_running, "host should stop gameplay commands after the result")
	_check(current_scene.scoreboard.result_panel.visible, "host should show the complete result panel")
	_check(await _wait_until(func() -> bool: return session.players.size() <= 1, 600), "client should acknowledge the synchronized result by leaving")


func _run_client() -> void:
	await _frames(20)
	_check(session.join_room("127.0.0.1", "计分客户端", "nailoong", port) == OK, "client should join the room")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 360), "client should receive the lobby")
	session.set_local_ready(true)
	_check(await _wait_for_match(), "client should enter the match")
	_check(await _wait_until(func() -> bool: return bool(current_scene.scoreboard.current_state.get("ended", false)), 360), "client should receive the authoritative result state")
	_check(int(current_scene.authority_presentation.match_rule_counts_by_kind.get("kill_announcement", 0)) == 1, "client should consume one reliable kill announcement")
	_check(int(current_scene.authority_presentation.match_rule_counts_by_kind.get("match_ended", 0)) == 1, "client should consume one reliable match-end event")
	_check(current_scene.scoreboard.result_panel.visible, "client should show the result panel")
	_check(not current_scene.command_gateway.accepting_commands and not current_scene.match_running, "client should stop accepting local commands after the result")
	var rows := current_scene.scoreboard.current_state.get("stats", []) as Array
	_check(rows.size() == 2 and _total_kills(rows) == 1 and _total_deaths(rows) == 1, "client scoreboard should contain synchronized K/D/A totals")
	session.close_session()


func _wait_for_match() -> bool:
	if not await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 360):
		return false
	return await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == BrawlNetworkSession.MATCH_SCENE, 180)


func _remote_actor() -> CombatActor:
	for peer_id_value in current_scene.actors_by_peer.keys():
		if int(peer_id_value) != BrawlNetworkSession.SERVER_PEER_ID:
			return current_scene.actors_by_peer[peer_id_value] as CombatActor
	return null


func _total_kills(rows: Array) -> int:
	var total := 0
	for value in rows:
		total += int((value as Dictionary).get("kills", 0))
	return total


func _total_deaths(rows: Array) -> int:
	var total := 0
	for value in rows:
		total += int((value as Dictionary).get("deaths", 0))
	return total


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
