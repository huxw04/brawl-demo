extends SceneTree

var role := "client"
var port := 24607
var failures: Array[String] = []
var session: BrawlNetworkSession
var rejected_commands := 0
var last_rejection := ""
var ownership_rejected := false
var continuous_semantics_rejected := false
var sequence_fault_rejected := false
var received_entity_events := 0
var received_entity_snapshots := 0
var accepted_results_by_client_sequence: Dictionary = {}
var rejected_results_by_client_sequence: Dictionary = {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	_run.call_deferred()


func _run() -> void:
	session = root.get_node("NetworkSession") as BrawlNetworkSession
	session.command_result_received.connect(_on_command_result)
	session.authoritative_event_received.connect(func(_packet: Dictionary) -> void: received_entity_events += 1)
	session.entity_snapshot_received.connect(func(_packet: Dictionary) -> void: received_entity_snapshots += 1)
	if role == "host":
		await _run_host()
	else:
		await _run_client()
	if failures.is_empty():
		print("NETWORK_STAGE_C_%s_PASS" % role.to_upper())
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
	_check(session.host_room("房主测试", "cheems_samurai", port) == OK, "host should bind the Stage A port")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 2, 300), "host should receive one localhost client")
	_check(await _wait_until(func() -> bool: return session.can_host_start(), 300), "host should receive the client's profile and ready state")
	if session.can_host_start():
		_check(session.host_start_match(), "host should start when both peers are ready")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 300), "host should receive every loaded acknowledgement")
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == BrawlNetworkSession.MATCH_SCENE, 120), "host should enter the synchronized match scene")
	_check((session.match_config.get("participants", []) as Array).size() == 2, "host match config should contain both players exactly once")
	_check(current_scene.match_authority != null and current_scene.match_replica == null, "host should own the only MatchAuthority")
	await _exercise_authority_movement(true)
	await _exercise_stage_c_combat(true)
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("ability_vfx", 0)) >= 4, 600), "host should consume Nailoong basic, roll, fire and laugh one-shot effects")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("nailoong_takeoff", 0)) > 0 and int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("nailoong_landing", 0)) > 0, 600), "host should consume Nailoong's authoritative leap endpoints")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("nailoong_heal_tick", 0)) > 0, 600), "host should consume Nailoong's healing tick effect")
	var host_actor_id := _actor_id_for_peer(BrawlNetworkSession.SERVER_PEER_ID)
	var client_actor_id := 0
	for participant_value in session.match_config.get("participants", []):
		var participant := participant_value as Dictionary
		if int(participant.get("peer_id", 0)) != BrawlNetworkSession.SERVER_PEER_ID:
			client_actor_id = int(participant.get("actor_id", 0))
	_check(await _wait_until(func() -> bool: return _history_has_types(current_scene.command_stream.history, client_actor_id, [BattleCommand.Type.MOVE_TO, BattleCommand.Type.STOP, BattleCommand.Type.JUMP, BattleCommand.Type.ROLL, BattleCommand.Type.BASIC_ATTACK, BattleCommand.Type.CAST_ABILITY, BattleCommand.Type.BEGIN_ABILITY, BattleCommand.Type.END_ABILITY, BattleCommand.Type.CANCEL_ABILITY]), 900), "host should retain the client's full authority combat sequence before shutdown")
	# The client's third STOP is a protocol-level test completion acknowledgement;
	# the second is the one accepted packet from the sequence fault injection.
	# Waiting only for END/CANCEL was racy: those commands can reach the host before
	# the resulting cooldown/status snapshots reach the client.
	_check(await _wait_until(func() -> bool: return _history_type_count(current_scene.command_stream.history, client_actor_id, BattleCommand.Type.STOP) >= 3, 600), "host should wait for the client's combat and sequence-fault assertions before shutdown")
	var host_move_count := 0
	for command in current_scene.command_stream.history:
		if command.actor_id == host_actor_id and command.type == BattleCommand.Type.MOVE_TO:
			host_move_count += 1
	_check(host_move_count == 2, "host movement commands should execute once and a forged client actor_id must not enter the authority stream")
	session.close_session()


func _run_client() -> void:
	await _frames(20)
	_check(session.join_room("127.0.0.1", "客户测试", "nailoong", port) == OK, "client should begin connecting to localhost")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 300), "client should complete handshake and receive the lobby")
	_check(session.roster().size() == 2, "client roster should match the host roster")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.IN_MATCH, 300), "client should load and receive the synchronized start")
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == BrawlNetworkSession.MATCH_SCENE, 120), "client should enter the synchronized match scene")
	_check((session.match_config.get("participants", []) as Array).size() == 2, "client match config should contain both players exactly once")
	_check(current_scene.match_authority == null and current_scene.match_replica != null, "client should use a MatchReplica instead of MatchAuthority")
	_check(not current_scene.command_runtime.running and current_scene.command_runtime.motors.is_empty(), "client must not run combat command motors")
	var replica_actor := current_scene.local_actor as CombatActor
	_check(replica_actor.authority_replica_mode and not replica_actor.is_physics_processing(), "client actors must not advance authoritative physics")
	session.state_snapshot_received.disconnect(current_scene._on_state_snapshot)
	replica_actor.global_position = Vector3(99.0, 9.0, 99.0)
	replica_actor.hp = 1.0
	replica_actor.cooldowns["skill_q"] = 999.0
	await _frames(24)
	_check(replica_actor.global_position.distance_to(Vector3(99.0, 9.0, 99.0)) < 0.001 and is_equal_approx(replica_actor.hp, 1.0), "snapshot blackout should leave deliberately corrupted replica state untouched")
	session.state_snapshot_received.connect(current_scene._on_state_snapshot)
	_check(await _wait_until(func() -> bool: return replica_actor.global_position.length() < 20.0, 180), "next authority snapshot should repair a deliberately corrupted client position")
	_check(await _wait_until(func() -> bool: return replica_actor.hp > 1.0, 180), "next authority snapshot should repair deliberately corrupted client health")
	_check(await _wait_until(func() -> bool: return not replica_actor.cooldowns.has("skill_q") or float(replica_actor.cooldowns.get("skill_q", 999.0)) < 10.0, 180), "next authority snapshot should repair a deliberately corrupted client cooldown")
	await _exercise_authority_movement(false)
	await _exercise_stage_c_combat(false)
	var authority_sequence_before_malformed: int = int(current_scene.command_gateway.last_authoritative_sequence)
	var malformed_begin := BattleCommand.create(_actor_id_for_peer(session.local_peer_id()), BattleCommand.Type.BEGIN_ABILITY, current_scene.local_actor.global_position)
	malformed_begin.ability_id = "skill_e"
	current_scene.command_gateway.submit(malformed_begin)
	_check(await _wait_until(func() -> bool: return continuous_semantics_rejected, 120), "server should reject BEGIN_ABILITY for a non-held skill without broadcasting it")
	await _frames(4)
	_check(current_scene.command_gateway.last_authoritative_sequence == authority_sequence_before_malformed, "a rejected continuous-command transition must not enter the authoritative broadcast sequence")
	var forged := BattleCommand.create(_actor_id_for_peer(BrawlNetworkSession.SERVER_PEER_ID), BattleCommand.Type.MOVE_TO, Vector3.ZERO)
	current_scene.command_gateway.submit(forged)
	_check(await _wait_until(func() -> bool: return ownership_rejected, 120), "server should explicitly reject a forged actor_id and explain the ownership failure")
	# Deliver a future sequence before an older packet, then duplicate the
	# accepted future packet. Authority must execute the STOP only once.
	var old_sequence := session.next_client_sequence
	session.next_client_sequence += 2
	var raw_stop := BattleCommand.create(_actor_id_for_peer(session.local_peer_id()), BattleCommand.Type.STOP)
	var future_packet := {
		"protocol_version": BrawlNetworkSession.PROTOCOL_VERSION,
		"match_id": int(session.match_config.get("match_id", 0)),
		"client_sequence": old_sequence + 1,
		"client_tick": 0,
		"command": raw_stop.to_packet(),
	}
	var old_packet := future_packet.duplicate(true)
	old_packet["client_sequence"] = old_sequence
	session._request_command.rpc_id(BrawlNetworkSession.SERVER_PEER_ID, future_packet)
	session._request_command.rpc_id(BrawlNetworkSession.SERVER_PEER_ID, old_packet)
	session._request_command.rpc_id(BrawlNetworkSession.SERVER_PEER_ID, future_packet)
	_check(await _wait_until(func() -> bool:
		return sequence_fault_rejected \
			and int(accepted_results_by_client_sequence.get(old_sequence + 1, 0)) == 1 \
			and int(rejected_results_by_client_sequence.get(old_sequence + 1, 0)) == 1 \
			and int(rejected_results_by_client_sequence.get(old_sequence, 0)) == 1
	, 120), "server should execute the future operation once and reject its duplicate plus the reordered older packet")
	# A third valid STOP tells the host that all client-side state assertions have
	# completed and it is now safe to close the peer connection.
	var completion := BattleCommand.create(_actor_id_for_peer(session.local_peer_id()), BattleCommand.Type.STOP)
	current_scene.command_gateway.submit(completion)
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE, 300), "client should leave the session when the host closes it")
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == "res://scenes/launcher.tscn", 120), "client should return to the launcher after host shutdown")
	_check("房主已离开" in session.last_error, "client should receive a visible host shutdown reason")


func _exercise_authority_movement(host: bool) -> void:
	var own_peer_id := BrawlNetworkSession.SERVER_PEER_ID if host else session.local_peer_id()
	var remote_peer_id := session.local_peer_id() if host else BrawlNetworkSession.SERVER_PEER_ID
	if host:
		for participant_value in session.match_config.get("participants", []):
			var participant := participant_value as Dictionary
			if int(participant.get("peer_id", 0)) != BrawlNetworkSession.SERVER_PEER_ID:
				remote_peer_id = int(participant.get("peer_id", 0))
		var own_move := BattleCommand.create(_actor_id_for_peer(own_peer_id), BattleCommand.Type.MOVE_TO, Vector3(-3.0, 0.0, 1.0))
		current_scene.command_gateway.submit(own_move)
	else:
		var own_move := BattleCommand.create(_actor_id_for_peer(own_peer_id), BattleCommand.Type.MOVE_TO, Vector3(3.0, 0.0, 1.0))
		current_scene.command_gateway.submit(own_move)
	var own_target_x := -3.0 if host else 3.0
	var remote_target_x := 3.0 if host else -3.0
	_check(await _wait_until(func() -> bool: return absf((current_scene.actors_by_peer[own_peer_id] as CombatActor).global_position.x - own_target_x) < 0.35, 300), "local authority-confirmed MOVE_TO should reach its target")
	_check(await _wait_until(func() -> bool: return absf((current_scene.actors_by_peer[remote_peer_id] as CombatActor).global_position.x - remote_target_x) < 0.45, 300), "remote actor should consume the same authority command and snapshot correction")
	var own_actor := current_scene.actors_by_peer[own_peer_id] as CombatActor
	if not host:
		for target in [Vector3(4.2, 0.0, 0.4), Vector3(2.4, 0.0, -2.7), Vector3(4.3, 0.0, -2.8)]:
			current_scene.command_gateway.submit(BattleCommand.create(own_actor.battle_id, BattleCommand.Type.MOVE_TO, target))
		_check(await _wait_until(func() -> bool: return Vector2(own_actor.global_position.x - 4.3, own_actor.global_position.z + 2.8).length() < 0.45, 360), "rapid destination changes should converge on the last path around the test wall")
	current_scene.command_gateway.submit(BattleCommand.create(own_actor.battle_id, BattleCommand.Type.STOP))
	await _frames(8)
	current_scene.command_gateway.submit(BattleCommand.create(own_actor.battle_id, BattleCommand.Type.JUMP))
	_check(await _wait_until(func() -> bool: return own_actor.global_position.y > 0.16, 90), "authority-confirmed JUMP should become visible")
	_check(await _wait_until(func() -> bool: return _actor_landed(own_actor), 150), "actor should land before the roll test")
	var roll := BattleCommand.create(own_actor.battle_id, BattleCommand.Type.ROLL)
	roll.direction = Vector3.LEFT if host else Vector3.RIGHT
	current_scene.command_gateway.submit(roll)
	_check(await _wait_until(func() -> bool: return own_actor.roll_remaining > 0.0, 90), "authority-confirmed ROLL should execute")
	if host:
		_check(_history_has_types(current_scene.command_stream.history, own_actor.battle_id, [BattleCommand.Type.MOVE_TO, BattleCommand.Type.STOP, BattleCommand.Type.JUMP, BattleCommand.Type.ROLL]), "authority history should include every movement command type")
	else:
		_check(current_scene.command_stream.history.is_empty(), "read-only client must not replay authority commands into a local combat stream")


func _exercise_stage_c_combat(host: bool) -> void:
	var own_peer_id := BrawlNetworkSession.SERVER_PEER_ID if host else session.local_peer_id()
	var remote_peer_id := session.local_peer_id() if host else BrawlNetworkSession.SERVER_PEER_ID
	if host:
		for participant_value in session.match_config.get("participants", []):
			var participant := participant_value as Dictionary
			if int(participant.get("peer_id", 0)) != BrawlNetworkSession.SERVER_PEER_ID:
				remote_peer_id = int(participant.get("peer_id", 0))
	var own_actor := current_scene.actors_by_peer[own_peer_id] as CombatActor
	var remote_actor := current_scene.actors_by_peer[remote_peer_id] as CombatActor
	_check(await _wait_until(func() -> bool: return own_actor.roll_remaining <= 0.0, 120), "roll should finish before combat command checks")
	var close_target := Vector3(-0.6, 0.0, 1.0) if host else Vector3(0.6, 0.0, 1.0)
	current_scene.command_gateway.submit(BattleCommand.create(own_actor.battle_id, BattleCommand.Type.MOVE_TO, close_target))
	_check(await _wait_until(func() -> bool: return Vector2(own_actor.global_position.x - close_target.x, own_actor.global_position.z - close_target.z).length() < 0.35, 720), "combatants should move into attack range through the authority stream")
	_check(await _wait_until(func() -> bool: return own_actor.global_position.distance_to(remote_actor.global_position) < 1.6, 720), "both peers should observe the same close combat setup")
	_check(await _wait_until(func() -> bool: return remote_actor.current_ability == null and remote_actor.roll_remaining <= 0.0, 240), "remote actor should finish its movement action before combat checks")
	if not host:
		_check(await _wait_until(func() -> bool: return own_actor.hp < own_actor.definition.max_hp, 360), "client should observe the host's opening basic attack before retaliating")
	var remote_hp_before := remote_actor.hp
	current_scene.command_gateway.submit(BattleCommand.create(own_actor.battle_id, BattleCommand.Type.BASIC_ATTACK, remote_actor.global_position))
	_check(await _wait_until(func() -> bool: return remote_actor.hp < remote_hp_before, 240), "authority-confirmed basic attack should damage the remote actor")
	_check(await _wait_until(func() -> bool: return own_actor.current_ability == null, 240), "basic attack should finish before the next combat command")
	if host:
		var client_basic_landed := await _wait_until(func() -> bool: return own_actor.hp < own_actor.definition.max_hp, 360)
		_check(client_basic_landed, "host authority should receive the client's basic attack before the skill sequence")
		_check(await _wait_until(func() -> bool: return own_actor.hurt_remaining <= 0.0 and own_actor.current_ability == null, 120), "host hit recovery should finish before casting the directional skill")
		var hp_before_q := remote_actor.hp
		var q := BattleCommand.create(own_actor.battle_id, BattleCommand.Type.CAST_ABILITY, remote_actor.global_position)
		q.ability_id = "skill_q"
		current_scene.command_gateway.submit(q)
		_check(await _wait_until(func() -> bool: return float(own_actor.cooldowns.get("skill_q", 0.0)) > 0.0, 120), "directional skill should enter authoritative cooldown")
		_check(await _wait_until(func() -> bool: return remote_actor.hp < hp_before_q, 240), "Cheems projectile skill should produce authoritative damage")
		own_actor.apply_status(CombatStatuses.slow(4.0, 0.65), own_actor.battle_id)
	else:
		_check(await _wait_until(func() -> bool: return float(remote_actor.cooldowns.get("skill_q", 0.0)) > 0.0, 360), "remote Cheems cooldown should arrive before the client starts its own ability sequence")
		_check(await _wait_until(func() -> bool: return current_scene.match_replica.entity_spawn_count > 0, 180), "client should create a passive Cheems sword-wave replica from authority data")
		_check(await _wait_until(func() -> bool: return current_scene.match_replica.entity_snapshot_apply_count > 0, 180), "client should apply unreliable live snapshots to the sword-wave replica")
		_check(await _wait_until(func() -> bool: return current_scene.match_replica.entity_motion_observed_count > 0, 180), "successive authority snapshots should visibly advance the sword-wave replica")
		_check(await _wait_until(func() -> bool: return current_scene.match_replica.entity_remove_count > 0, 240), "client should remove the sword-wave replica after its authoritative hit/despawn")
		_check(received_entity_events >= 2, "client should receive reliable spawn and destroy events")
		_check(received_entity_snapshots > 0, "client should receive the separate unreliable entity snapshot stream")
		_check(current_scene.find_children("*", "CombatProjectile", true, false).is_empty(), "client must never create an authoritative CombatProjectile simulation node")
		_check(await _wait_until(func() -> bool: return own_actor.hurt_remaining <= 0.0 and own_actor.current_ability == null, 180), "client hit recovery should finish before its ability sequence")
		_check(await _wait_until(func() -> bool: return remote_actor.status_controller.has_visual("slow"), 120), "status effects should restore from compact per-actor snapshots")
		var ability_effects_before_roll := int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("ability_vfx", 0))
		var roll_started := false
		for _attempt in range(4):
			var roll_skill := BattleCommand.create(own_actor.battle_id, BattleCommand.Type.CAST_ABILITY, own_actor.global_position)
			roll_skill.ability_id = "skill_q"
			current_scene.command_gateway.submit(roll_skill)
			roll_started = await _wait_until(func() -> bool: return own_actor.current_ability != null and own_actor.current_ability.vfx_id == "nailoong_roll", 90)
			if roll_started:
				break
			await _frames(30)
		_check(roll_started, "non-directional Q should execute through the authority stream")
		_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("ability_vfx", 0)) > ability_effects_before_roll, 120), "Nailoong roll should deliver one reliable start effect")
		_check(await _wait_until(func() -> bool: return current_scene.find_children("NailoongRollDust", "MeshInstance3D", true, false).size() > 0, 90), "replica presentation should generate rolling dust at its own visual cadence")
		current_scene.command_gateway.submit(BattleCommand.create(own_actor.battle_id, BattleCommand.Type.CANCEL_ABILITY))
		_check(await _wait_until(func() -> bool: return own_actor.current_ability == null, 120), "CANCEL_ABILITY should stop Nailoong rolling")
		var ability_effects_before_fire := int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("ability_vfx", 0))
		var held_skill_started := false
		for _attempt in range(4):
			await _wait_until(func() -> bool: return own_actor.current_ability == null and own_actor.hurt_remaining <= 0.0, 120)
			var begin_w := BattleCommand.create(own_actor.battle_id, BattleCommand.Type.BEGIN_ABILITY, remote_actor.global_position)
			begin_w.ability_id = "skill_w"
			current_scene.command_gateway.submit(begin_w)
			held_skill_started = await _wait_until(func() -> bool: return own_actor.current_ability != null and own_actor.current_ability.ability_id == "skill_w", 120)
			if held_skill_started:
				break
			await _frames(30)
		_check(held_skill_started, "BEGIN_ABILITY should start a held skill")
		_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("ability_vfx", 0)) > ability_effects_before_fire, 120), "Nailoong fire breath should deliver one reliable muzzle effect")
		if held_skill_started:
			await _frames(18)
			var end_w := BattleCommand.create(own_actor.battle_id, BattleCommand.Type.END_ABILITY)
			end_w.ability_id = "skill_w"
			current_scene.command_gateway.submit(end_w)
			_check(await _wait_until(func() -> bool: return float(own_actor.cooldowns.get("skill_w", 0.0)) > 0.0, 150), "END_ABILITY should finish the held skill and start cooldown")
		_check(await _wait_until(func() -> bool: return int(current_scene.match_replica.entity_spawn_counts_by_vfx.get("nailoong_fire_breath", 0)) > 0, 180), "Nailoong fire breath should replicate its projectile family without client-side combat simulation")
		_check(await _wait_until(func() -> bool: return own_actor.current_ability == null and own_actor.hurt_remaining <= 0.0, 180), "fire breath should finish before leap")
		var leap := BattleCommand.create(own_actor.battle_id, BattleCommand.Type.CAST_ABILITY, own_actor.global_position + Vector3(0.0, 0.0, -1.2))
		leap.ability_id = "skill_e"
		current_scene.command_gateway.submit(leap)
		_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("nailoong_takeoff", 0)) > 0, 180), "client should receive the authoritative leap takeoff")
		_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("nailoong_landing", 0)) > 0, 180), "client should receive the authoritative leap landing")
		_check(await _wait_until(func() -> bool: return own_actor.current_ability == null and own_actor.hurt_remaining <= 0.0, 180), "leap should finish before laugh")
		var laugh := BattleCommand.create(own_actor.battle_id, BattleCommand.Type.CAST_ABILITY)
		laugh.ability_id = "ultimate"
		current_scene.command_gateway.submit(laugh)
		_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("nailoong_heal_tick", 0)) > 0, 240), "client should receive authoritative healing ticks")
		_check(await _wait_until(func() -> bool: return float(remote_actor.cooldowns.get("skill_q", 0.0)) > 0.0, 180), "combat cooldowns should arrive in gated authority snapshots")


func _actor_id_for_peer(peer_id: int) -> int:
	for participant_value in session.match_config.get("participants", []):
		var participant := participant_value as Dictionary
		if int(participant.get("peer_id", 0)) == peer_id:
			return int(participant.get("actor_id", 0))
	return 0


func _actor_landed(actor: CombatActor) -> bool:
	return actor.global_position.y <= 0.08 if actor.authority_replica_mode else actor.is_on_floor()


func _history_has_types(history: Array[BattleCommand], actor_id: int, types: Array) -> bool:
	for type_value in types:
		var found := false
		for command in history:
			if command.actor_id == actor_id and command.type == int(type_value):
				found = true
				break
		if not found:
			return false
	return true


func _history_type_count(history: Array[BattleCommand], actor_id: int, type: int) -> int:
	var count := 0
	for command in history:
		if command.actor_id == actor_id and command.type == type:
			count += 1
	return count


func _on_command_result(client_sequence: int, accepted: bool, reason: String, _server_sequence: int) -> void:
	if accepted:
		accepted_results_by_client_sequence[client_sequence] = int(accepted_results_by_client_sequence.get(client_sequence, 0)) + 1
	else:
		rejected_results_by_client_sequence[client_sequence] = int(rejected_results_by_client_sequence.get(client_sequence, 0)) + 1
	if not accepted:
		rejected_commands += 1
		last_rejection = reason
		if "不属于发送者" in reason:
			ownership_rejected = true
		if "服务器战斗状态" in reason:
			continuous_semantics_rejected = true
		if "重复或倒退" in reason:
			sequence_fault_rejected = true


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
