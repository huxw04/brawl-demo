extends SceneTree

var role := "client"
var port := 24627
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
		print("NETWORK_HERO_EFFECTS_%s_PASS" % role.to_upper())
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
	_check(session.host_room("英雄事件房主", "sword_shield_dog", port) == OK, "host should create the hero-effect room")
	session.set_local_ready(true)
	_check(await _wait_until(func() -> bool: return session.players.size() == 2 and session.can_host_start(), 360), "host should receive the Bear client")
	if session.can_host_start():
		session.host_start_match()
	_check(await _wait_for_match(), "host should enter the hero-effect match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(-0.5, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(-0.5, 0.05, 0.0)) < 0.35 and remote.global_position.distance_to(Vector3(0.5, 0.05, 0.0)) < 0.45, 720), "both actors should meet inside poison range")
	var guard := BattleCommand.create(own.battle_id, BattleCommand.Type.BEGIN_ABILITY)
	guard.ability_id = "skill_q"
	current_scene.command_gateway.submit(guard)
	_check(await _wait_until(func() -> bool: return own.current_ability != null and own.current_ability.ability_id == "skill_q" and own.ability_phase == "active", 180), "host should enter authoritative guard before Bear attacks")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("sword_shield_block", 0)) > 0, 240), "blocked Bear attack should emit a reliable shield flash")
	var end_guard := BattleCommand.create(own.battle_id, BattleCommand.Type.END_ABILITY)
	end_guard.ability_id = "skill_q"
	current_scene.command_gateway.submit(end_guard)
	_check(await _wait_until(func() -> bool: return own.current_ability == null, 180), "guard should finish before transformation")
	var transform := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY)
	transform.ability_id = "ultimate"
	current_scene.command_gateway.submit(transform)
	_check(await _wait_until(func() -> bool: return own.transformed, 180), "host ultimate should transform authoritatively")
	_check(int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("sword_shield_transform", 0)) == 1, "host should consume one transform event")
	# Missing-health poison intentionally deals zero damage to a full-health target.
	# Seed damage on authority so this test also exercises the delayed burst event.
	own.hp = 70.0
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_poison_mark", 0)) > 0, 360), "host should receive Bear's poison mark event")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_poison_burst", 0)) > 0, 360), "host should receive Bear's delayed poison burst event")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_ambush", 0)) > 0, 360), "host should receive Bear's ambush endpoint event")
	_check(int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_backstab", 0)) > 0, "ambush damage should emit its authoritative backstab event")
	_check(await _wait_until(func() -> bool: return _history_type_count(remote.battle_id, BattleCommand.Type.STOP) >= 2, 360), "host should wait for client presentation assertions")
	session.close_session()


func _run_client() -> void:
	await _frames(20)
	_check(session.join_room("127.0.0.1", "贝爷客户端", "bear_grylls_jungler", port) == OK, "client should join the hero-effect room")
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.LOBBY, 360), "client should receive the lobby")
	session.set_local_ready(true)
	_check(await _wait_for_match(), "client should enter the hero-effect match")
	var own := current_scene.local_actor as CombatActor
	var remote := current_scene._first_remote_actor() as CombatActor
	current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.MOVE_TO, Vector3(0.5, 0.0, 0.0)))
	_check(await _wait_until(func() -> bool: return own.global_position.distance_to(Vector3(0.5, 0.05, 0.0)) < 0.45 and remote.global_position.distance_to(Vector3(-0.5, 0.05, 0.0)) < 0.45, 720), "client should observe the shared center setup")
	_check(await _wait_until(func() -> bool: return remote.current_ability != null and remote.current_ability.ability_id == "skill_q" and remote.ability_phase == "active", 240), "client should observe the host's guard state")
	var blocked_basic := BattleCommand.create(own.battle_id, BattleCommand.Type.BASIC_ATTACK, remote.global_position)
	current_scene.command_gateway.submit(blocked_basic)
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("sword_shield_block", 0)) > 0, 180), "client should receive the reliable block confirmation")
	_check(await _wait_until(func() -> bool: return own.current_ability == null, 180), "Bear basic should finish before transformation sequence")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("sword_shield_transform", 0)) > 0, 240), "client should receive the reliable transform event")
	_check(await _wait_until(func() -> bool: return remote.transformed and remote.sprite.texture == remote.definition.transformed_sprite_texture, 180), "client snapshot and event should agree on transformed presentation")
	var poison := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY)
	poison.ability_id = "skill_w"
	current_scene.command_gateway.submit(poison)
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_poison_mark", 0)) > 0, 240), "client should receive its reliable poison mark event")
	_check(remote.get_node_or_null("BearPoisonMark") != null, "client should attach the poison marker to the stable remote actor")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_poison_burst", 0)) > 0, 300), "client should receive the delayed poison burst")
	await _wait_until(func() -> bool: return own.current_ability == null, 120)
	var ambush := BattleCommand.create(own.battle_id, BattleCommand.Type.CAST_ABILITY, remote.global_position)
	ambush.ability_id = "ultimate"
	current_scene.command_gateway.submit(ambush)
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_ambush", 0)) > 0, 240), "client should receive authoritative ambush endpoints")
	_check(await _wait_until(func() -> bool: return int(current_scene.authority_presentation.hero_effect_counts_by_vfx.get("bear_backstab", 0)) > 0, 120), "client should receive the backstab confirmation effect")
	for _index in range(2):
		current_scene.command_gateway.submit(BattleCommand.create(own.battle_id, BattleCommand.Type.STOP))
		await _frames(4)
	_check(await _wait_until(func() -> bool: return session.state == BrawlNetworkSession.State.OFFLINE, 360), "client should finish when host closes the focused test")


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
