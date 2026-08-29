extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var authority := MatchAuthority.new()
	root.add_child(authority)
	var presentation := AuthorityEventPresentation.new()
	root.add_child(presentation)
	presentation.setup(authority)

	var fixed_entity := Node3D.new()
	root.add_child(fixed_entity)
	_check(authority.register_entity(fixed_entity, &"actor", 5, {"name": "fixed"}) == 5, "requested stable entity id should be preserved")
	var dynamic_entity := Node3D.new()
	root.add_child(dynamic_entity)
	_check(authority.register_entity(dynamic_entity, &"projectile") == 6, "automatic ids should continue monotonically after requested ids")
	authority.unregister_entity(6, &"test_cleanup")
	var next_entity := Node3D.new()
	root.add_child(next_entity)
	_check(authority.register_entity(next_entity, &"projectile") == 7, "destroyed entity ids must never be reused")
	_check(authority.event_log.size() == 4, "three spawns and one destroy should produce four events")
	for index in range(authority.event_log.size()):
		_check(authority.event_log[index].event_id == index + 1, "event ids should be strictly monotonic")
	var round_trip := AuthoritativeEvent.from_packet(authority.event_log[0].to_packet())
	_check(round_trip.event_id == 1 and round_trip.entity_id == 5 and round_trip.event_type == AuthoritativeEvent.ENTITY_SPAWNED, "authoritative event packet should round-trip")
	_check(presentation.last_consumed_event_id == 4 and presentation.consumed_packets.size() == 4, "offline presentation should consume authority events immediately")

	# Exercise the real Cheems Q spawn path instead of only registering dummy nodes.
	var arena := ArenaWorld.new()
	arena.include_test_walls = false
	root.add_child(arena)
	var hero := CombatActor.new()
	root.add_child(hero)
	hero.setup(CheemsSamurai.create(), 1, "cheems", CombatActor.Relation.SELF)
	hero.battle_id = 1
	hero.global_position = Vector3(-4.0, 0.05, 0.0)
	hero.facing = Vector3.RIGHT
	authority.register_entity(hero, &"actor", hero.battle_id, hero.authoritative_actor_state())
	var target := CombatActor.new()
	root.add_child(target)
	target.setup(PlaceholderHero.create(), 2, "target", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	target.global_position = Vector3(5.0, 0.05, 0.0)
	authority.register_entity(target, &"actor", target.battle_id, target.authoritative_actor_state())
	await _physics_frames(4)
	var hostile_ability := AbilityDefinition.new()
	hostile_ability.ability_id = "hostile_test_projectile"
	hostile_ability.vfx_id = "generic_test_projectile"
	hostile_ability.projectile_speed = 0.0
	hostile_ability.projectile_lifetime = 5.0
	hostile_ability.projectile_radius = 0.28
	var hostile_projectile := CombatEntityFactory.spawn_projectile(authority, root, target, hostile_ability, Vector3.LEFT, 800, Vector3(-3.0, 0.57, 0.0))
	var hostile_projectile_id := hostile_projectile.entity_id
	_check(hero.try_ability("skill_q", true), "Cheems Q should start in authority integration test")
	await _physics_frames(18)
	_check(authority.entity(hostile_projectile_id) == null, "Cheems Q should authoritatively destroy an enemy projectile in its path")
	var projectiles := get_nodes_in_group("combat_projectiles")
	_check(projectiles.size() == 1, "Cheems Q should create one registered projectile")
	if not projectiles.is_empty():
		var projectile := projectiles[0] as CombatProjectile
		_check(projectile.entity_id > 7 and authority.entity(projectile.entity_id) == projectile, "Cheems Q projectile should receive a stable entity id")
		_check(projectile.visual == null, "authority-backed Cheems Q should not build combat-owned sword-wave visuals")
		var event_visual := presentation.entity_visuals.get(projectile.entity_id) as ProjectileEventVisual
		_check(event_visual != null, "Cheems Q spawn event should create a presentation-owned sword-wave visual")
		var descriptor: Dictionary = authority.entity_descriptors.get(projectile.entity_id, {})
		var initial_state: Dictionary = descriptor.get("initial_state", {})
		_check(descriptor.get("entity_kind") == "projectile" and initial_state.get("ability_id") == "skill_q", "Cheems Q spawn event should identify projectile kind and ability")
		var digest := authority.state_digest()
		var projectile_snapshot := _snapshot_for_entity(digest.get("entities", []), projectile.entity_id)
		_check(projectile_snapshot.get("entity_kind") == "projectile" and projectile_snapshot.get("vfx_id") == "sword_wave", "authority digest should contain the live projectile snapshot")
		if event_visual != null:
			_check(event_visual.global_position.distance_to(projectile.global_position) < 0.001, "event-driven visual should follow its authoritative projectile")
		var projectile_id := projectile.entity_id
		projectile.queue_free()
		await _physics_frames(2)
		_check(authority.entity(projectile_id) == null, "queue_free should unregister an authoritative entity")
		_check(not presentation.entity_visuals.has(projectile_id), "destroy event should remove the presentation-owned projectile visual")
		var last_event: AuthoritativeEvent = authority.event_log.back()
		_check(last_event.event_type == AuthoritativeEvent.ENTITY_DESTROYED and last_event.entity_id == projectile_id, "projectile exit should emit a matching destroy event")

	var delayed_ability := AbilityDefinition.new()
	delayed_ability.ability_id = "factory_delayed"
	delayed_ability.delayed_delay = 5.0
	delayed_ability.delayed_radius = 1.2
	delayed_ability.delayed_damage = 1.0
	var delayed := CombatEntityFactory.spawn_delayed_attack(authority, root, hero, delayed_ability, 901, Vector3(1.0, 0.0, 2.0))
	var chu_definition := ChuYing.create()
	var stone := CombatEntityFactory.spawn_chu_ying_stone(authority, root, hero, chu_definition.ability_by_id("skill_q"), 902, Vector3(2.0, 0.0, 2.0))
	var barrier := CombatEntityFactory.spawn_chu_ying_barrier(authority, root, hero, chu_definition.ability_by_id("ultimate"), 903, Vector3.ZERO, Vector2(1.0, 1.5))
	_check(delayed.entity_id > 0 and stone.entity_id == delayed.entity_id + 1 and barrier.entity_id == stone.entity_id + 1, "all dynamic entity kinds should share the same monotonic factory id space")
	_check(delayed.indicator == null and stone.visual == null and barrier.get_children().is_empty(), "authority-backed world entities must not retain presentation meshes")
	_check(presentation.entity_visuals.get(delayed.entity_id) is WorldEntityEventVisual and presentation.entity_visuals.get(stone.entity_id) is WorldEntityEventVisual and presentation.entity_visuals.get(barrier.entity_id) is WorldEntityEventVisual, "authority events should own all three world-entity presentations")
	var factory_digest := authority.state_digest()
	_check(_snapshot_for_entity(factory_digest.get("entities", []), delayed.entity_id).get("entity_kind") == "delayed_attack", "delayed attacks should publish authoritative snapshots")
	_check(_snapshot_for_entity(factory_digest.get("entities", []), stone.entity_id).get("entity_kind") == "chu_ying_stone", "Chu Ying stones should publish authoritative snapshots")
	_check(_snapshot_for_entity(factory_digest.get("entities", []), barrier.entity_id).get("entity_kind") == "chu_ying_barrier", "Chu Ying barriers should publish authoritative snapshots")
	for entity in [delayed, stone, barrier]:
		entity.queue_free()
	await _physics_frames(2)
	var quick_delayed_ability := AbilityDefinition.new()
	quick_delayed_ability.ability_id = "quick_delayed"
	quick_delayed_ability.vfx_id = "shield_dog_heavy_chop"
	quick_delayed_ability.delayed_delay = 0.05
	quick_delayed_ability.delayed_radius = 1.0
	quick_delayed_ability.delayed_damage = 1.0
	var quick_delayed := CombatEntityFactory.spawn_delayed_attack(authority, root, hero, quick_delayed_ability, 904, Vector3(4.0, 0.0, 2.0))
	var quick_delayed_id := quick_delayed.entity_id
	await _physics_frames(6)
	_check(authority.entity(quick_delayed_id) == null, "detonated delayed attack should explicitly leave the authority registry")
	var detonation_event: AuthoritativeEvent = authority.event_log.back()
	_check(detonation_event.event_type == AuthoritativeEvent.ENTITY_DESTROYED and detonation_event.entity_id == quick_delayed_id and detonation_event.payload.get("reason") == "detonated", "delayed attack should publish a reliable detonation reason")
	_check(int(presentation.finished_entity_counts_by_kind.get("delayed_attack", 0)) > 0, "detonation event should finish the presentation-owned planted sword")

	var replay_presentation := AuthorityEventPresentation.new()
	root.add_child(replay_presentation)
	replay_presentation.replay(authority.event_log)
	_check(replay_presentation.last_consumed_event_id == authority.event_log.back().event_id, "a fresh presentation should replay the complete authority event log")
	_check(replay_presentation.consumed_packets.size() == authority.event_log.size(), "event replay should preserve event count")

	for node in [fixed_entity, dynamic_entity, next_entity, hero, target, arena, presentation, replay_presentation, authority]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	await _physics_frames(2)
	if failures.is_empty():
		print("Authority event and entity registry checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _snapshot_for_entity(snapshots: Array, entity_id: int) -> Dictionary:
	for snapshot_value in snapshots:
		var snapshot := snapshot_value as Dictionary
		if int(snapshot.get("entity_id", 0)) == entity_id:
			return snapshot
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
