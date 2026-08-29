extends SceneTree

var role := "client"
var port := 24617
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
		print("NETWORK_WORLD_ENTITIES_%s_PASS" % role.to_upper())
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
	_check(session.host_room("世界实体房主", "sword_shield_dog", port) == OK, "host should create the world-entity room")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 2 and session.can_host_start(), 360), "host should receive the Chu Ying client")
	if session.can_host_start():
		session.host_start_match()
	_check(await _wait_for_match(), "host should enter the world-entity match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(-1.0, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(-1.0, 0.05, 0.0)) < 0.45 and remote.global_position.distance_to(Vector3(1.0, 0.05, 0.0)) < 0.55, 720), "both actors should meet near the center")
	var heavy := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, Vector3(0.0, 0.0, 0.0))
	heavy.ability_id = "skill_w"
	current_scene.command_gateway.submit(heavy)
	_check(await _wait_until(func() -> bool: return _authority_has_kind("delayed_attack"), 180), "host W should create one authoritative delayed attack")
	_check(await _wait_until(func() -> bool: return not _authority_has_kind("delayed_attack"), 240), "delayed attack should detonate and leave authority registry")
	_check(await _wait_until(func() -> bool: return _authority_has_kind("chu_ying_stone"), 360), "host should receive Chu Ying Q and register its stone")
	_check(await _wait_until(func() -> bool: return not _authority_has_kind("chu_ying_stone"), 420), "Chu Ying board should consume the flying stone")
	_check(await _wait_until(func() -> bool: return _authority_has_kind("chu_ying_barrier"), 360), "Chu Ying R should create an authoritative rectangular barrier")
	var barrier := _authority_entity_of_kind("chu_ying_barrier") as ChuYingBarrier
	_check(barrier != null and barrier.trapped.has(own), "host actor should be captured by the barrier at creation")
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(-5.0, 0.0, 0.0)))
	await _frames(120)
	if barrier != null and is_instance_valid(barrier):
		var offset := own.global_position - barrier.global_position
		_check(absf(offset.x) < barrier.half_extents.x and absf(offset.z) < barrier.half_extents.y, "host authority should keep movement inside the replicated rectangle")
	_check(await _wait_until(func() -> bool: return _history_type_count(remote.battle_id, BattleCommand.Type.STOP) >= 2, 360), "host should wait for the client's world-entity assertions")
	session.close_session()


func _run_client() -> void:
	await _frames(20)
	_check(session.join_room("127.0.0.1", "褚赢客户端", "chu_ying", port) == OK, "client should join the world-entity room")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 360), "client should receive the lobby")
	session.set_local_ready(true)
	_check(await _wait_for_match(), "client should enter the world-entity match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(1.0, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(1.0, 0.05, 0.0)) < 0.45 and remote.global_position.distance_to(Vector3(-1.0, 0.05, 0.0)) < 0.55, 720), "client should observe the shared center setup")
	_check(await _wait_until(func() -> bool: return int(current_scene.match_replica.entity_spawn_counts_by_kind.get("delayed_attack", 0)) > 0, 240), "client should create the planted-sword replica")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.finished_entity_counts_by_kind.get("delayed_attack", 0)) > 0, 300), "client should consume the reliable delayed detonation")
	await _wait_until(func() -> bool: return own.current_ability == null and own.hurt_remaining <= 0.0, 180)
	var q := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, Vector3(0.0, 0.0, 0.0))
	q.ability_id = "skill_q"
	var stone_started := false
	for _attempt in range(4):
		current_scene.command_gateway.submit(q)
		stone_started = await _wait_until(func() -> bool: return int(current_scene.match_replica.entity_spawn_counts_by_kind.get("chu_ying_stone", 0)) > 0, 90)
		if stone_started:
			break
		await _frames(24)
	_check(stone_started, "client should receive its falling-stone replica")
	_check(await _wait_until(func() -> bool:
		var stone := _replica_entity_of_kind("chu_ying_stone") as ReplicaCombatEntity
		return stone != null and stone.fall_remaining <= 0.0
	, 180), "stone replica should progress from falling to grounded")
	await _wait_until(func() -> bool: return own.current_ability == null, 120)
	var board := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, Vector3(0.0, 0.0, 0.0))
	board.ability_id = "skill_w"
	var board_started := false
	for _attempt in range(4):
		current_scene.command_gateway.submit(board)
		board_started = await _wait_until(func() -> bool: return int(current_scene.authority_presentation.world_effect_counts_by_vfx.get("chu_ying_board", 0)) > 0, 90)
		if board_started:
			break
		await _frames(24)
	_check(board_started, "client should receive the reliable board world effect")
	_check(await _wait_until(func() -> bool: return _replica_entity_of_kind("chu_ying_stone") == null, 240), "stone replica should fly to the board and be removed")
	await _wait_until(func() -> bool: return own.current_ability == null, 180)
	# Drop both reliable lifecycle events and complete entity snapshots at the
	# application boundary. State snapshots remain connected so we can observe
	# that authority accepted the cast before restoring the entity channels.
	session.authoritative_event_received.disconnect(current_scene._on_authoritative_event_received)
	session.entity_snapshot_received.disconnect(current_scene._on_entity_snapshot)
	var barrier_command := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, Vector3(-3.0, 0.0, 0.0))
	barrier_command.ability_id = "ultimate"
	var barrier_started := false
	for _attempt in range(4):
		current_scene.command_gateway.submit(barrier_command)
		barrier_started = await _wait_until(func() -> bool: return float(own.cooldowns.get("ultimate", 0.0)) > 0.0, 120)
		if barrier_started:
			break
		await _frames(24)
	_check(barrier_started and _replica_entity_of_kind("chu_ying_barrier") == null, "dropped event and snapshot should temporarily hide the authoritative barrier")
	await _frames(18)
	session.authoritative_event_received.connect(current_scene._on_authoritative_event_received)
	session.entity_snapshot_received.connect(current_scene._on_entity_snapshot)
	_check(await _wait_until(func() -> bool: return _replica_entity_of_kind("chu_ying_barrier") != null, 180), "next complete entity snapshot should recover the missed barrier spawn")
	var barrier_replica := _replica_entity_of_kind("chu_ying_barrier") as ReplicaCombatEntity
	_check(barrier_replica != null and barrier_replica.half_extents.x >= 1.9 and barrier_replica.half_extents.y >= 0.49, "barrier snapshot should retain its rectangular extents")
	await _frames(120)
	if barrier_replica != null and is_instance_valid(barrier_replica):
		var offset := remote.global_position - barrier_replica.global_position
		_check(absf(offset.x) < barrier_replica.half_extents.x + 0.08 and absf(offset.z) < barrier_replica.half_extents.y + 0.08, "client snapshot should show the host constrained inside the barrier")
	for _index in range(2):
		current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.STOP))
		await _frames(4)
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE, 360), "client should finish when host closes the focused test")


func _wait_for_match() -> bool:
	if role == "host":
		if not await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 360):
			return false
	else:
		if not await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 360):
			return false
	return await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == BrawlNetworkSession.MATCH_SCENE, 180)


func _authority_has_kind(kind: String) -> bool:
	return _authority_entity_of_kind(kind) != null


func _authority_entity_of_kind(kind: String) -> Node:
	if current_scene == null or current_scene.match_authority == null:
		return null
	for entity_id in current_scene.match_authority.entity_descriptors.keys():
		var descriptor := current_scene.match_authority.entity_descriptors[entity_id] as Dictionary
		if str(descriptor.get("entity_kind", "")) == kind:
			return current_scene.match_authority.entity(int(entity_id))
	return null


func _replica_entity_of_kind(kind: String) -> Node:
	if current_scene == null or current_scene.match_replica == null:
		return null
	for entity_value in current_scene.match_replica.entities_by_id.values():
		var entity := entity_value as ReplicaCombatEntity
		if entity != null and entity.entity_kind == kind:
			return entity
	return null


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
