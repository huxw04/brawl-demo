extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var definition := BrawlMapCatalog.default_network_map()
	var authority := MatchAuthority.new()
	root.add_child(authority)
	var manager := BrawlRespawnManager.new()
	root.add_child(manager)
	manager.setup(definition, BattleRng.new(20260828), authority, 0.12, 0.25)

	var victim := CombatActor.new()
	root.add_child(victim)
	victim.setup(CheemsSamurai.create(), 1, "victim", CombatActor.Relation.SELF)
	victim.battle_id = 1
	victim.reset_runtime(definition.spawn_position(0))
	var survivor := CombatActor.new()
	root.add_child(survivor)
	survivor.setup(PlaceholderHero.create(), 2, "survivor", CombatActor.Relation.ENEMY)
	survivor.battle_id = 2
	var occupied_spawn := definition.spawn_position(4)
	survivor.reset_runtime(occupied_spawn)
	manager.register_actor(victim, "initial_left")
	manager.register_actor(survivor, "north_west")

	var lethal := survivor.ability_by_id("basic")
	_check(victim.receive_hit(survivor, lethal, Vector3.RIGHT, 1, 9999.0), "lethal damage should be accepted")
	_check(victim.is_defeated and victim.respawn_remaining > 0.0, "defeat should immediately schedule a visible countdown")
	_check(_event_count(authority, "respawn_scheduled") == 1, "authority should emit one reliable respawn schedule event")
	_check(not victim.receive_hit(survivor, lethal, Vector3.RIGHT, 2, 1.0), "a defeated actor must remain unhittable")
	_check(await _wait_until(func() -> bool: return not victim.is_defeated, 60), "the authority manager should revive the actor after its deadline")
	_check(is_equal_approx(victim.hp, victim.definition.max_hp) and is_equal_approx(victim.stamina, victim.definition.max_stamina), "respawn should restore full health and stamina")
	_check(victim.spawn_protection_remaining > 0.0, "respawn should grant temporary spawn protection")
	_check(Vector2(victim.global_position.x - survivor.global_position.x, victim.global_position.z - survivor.global_position.z).length() >= BrawlRespawnManager.OCCUPIED_RADIUS, "safe selection should reject a spawn occupied by a living actor")
	_check(_is_spawn_point(definition, victim.global_position), "respawn should use one of the map's stable spawn points")
	_check(_event_count(authority, "actor_respawned") == 1, "authority should emit one reliable respawn completion event")
	var protected_hp := victim.hp
	_check(not victim.receive_hit(survivor, lethal, Vector3.RIGHT, 3, 10.0) and is_equal_approx(victim.hp, protected_hp), "spawn protection should reject incoming damage")
	_check(await _wait_until(func() -> bool: return victim.spawn_protection_remaining <= 0.0, 60), "spawn protection should expire on the authority clock")
	_check(victim.receive_hit(survivor, lethal, Vector3.RIGHT, 4, 1.0), "damage should work again after spawn protection expires")

	if failures.is_empty():
		print("Authority respawn, safe spawn, protection, and event checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _event_count(authority: MatchAuthority, kind: String) -> int:
	var count := 0
	for event in authority.event_log:
		if event.event_type == AuthoritativeEvent.MATCH_RULE and str(event.payload.get("event_kind", "")) == kind:
			count += 1
	return count


func _is_spawn_point(definition: BrawlMapDefinition, position: Vector3) -> bool:
	for spawn in definition.spawn_points:
		if (spawn.get("position", Vector3.ZERO) as Vector3).distance_to(position) < 0.01:
			return true
	return false


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _index in range(maximum_frames):
		if predicate.call():
			return true
		await physics_frame
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
