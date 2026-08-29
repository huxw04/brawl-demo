extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var replica := MatchReplica.new()
	root.add_child(replica)
	replica.setup(77)
	var presentation := AuthorityEventPresentation.new()
	root.add_child(presentation)
	presentation.setup_source(replica)
	var actor := CombatActor.new()
	root.add_child(actor)
	actor.setup(PlaceholderHero.create(), 1, "replica")
	actor.battle_id = 9
	replica.register_actor(actor)
	_check(actor.authority_replica_mode and not actor.is_physics_processing(), "registered replica actors must not run authoritative physics")
	_check(replica.apply_actor_snapshot(_snapshot(77, 10, 9, Vector3(3.0, 0.05, 2.0), 55.0, false, "basic")), "new matching snapshot should apply")
	_check(actor.global_position.distance_to(Vector3(3.0, 0.05, 2.0)) < 0.001, "replica should restore authoritative position")
	_check(is_equal_approx(actor.hp, 55.0) and actor.current_ability != null and actor.current_ability.ability_id == "basic", "replica should restore health and action state")
	_check(not replica.apply_actor_snapshot(_snapshot(77, 9, 9, Vector3.ZERO, 1.0, false)), "older per-actor snapshots should be ignored")
	_check(not replica.apply_actor_snapshot(_snapshot(78, 11, 9, Vector3.ZERO, 1.0, false)), "snapshots from another match should be ignored")
	_check(is_equal_approx(actor.hp, 55.0), "ignored snapshots must not mutate replica state")
	_check(replica.apply_actor_snapshot(_snapshot(77, 11, 9, Vector3(3.0, 0.05, 2.0), 0.0, true)), "new defeat snapshot should apply")
	_check(actor.is_defeated, "defeat must be restored from authority")
	_check(replica.apply_actor_snapshot(_snapshot(77, 12, 9, Vector3(-1.0, 0.05, 1.0), 100.0, false)), "new revival snapshot should apply")
	_check(not actor.is_defeated and actor.collision_layer == 0, "revived replica should remain passive and non-authoritative")
	var sword_snapshot := _entity_snapshot(77, 20, [{
		"entity_id": 31,
		"entity_kind": "projectile",
		"vfx_id": "sword_wave",
		"position": [10000, 500, 20000],
		"direction": [10000, 0, 0],
	}])
	_check(replica.apply_entity_snapshot(sword_snapshot), "a new entity snapshot should apply")
	var recovered := replica.entity(31) as ReplicaCombatEntity
	_check(recovered != null and recovered.global_position.distance_to(Vector3(1.0, 0.05, 2.0)) < 0.001, "a snapshot must recover a missed reliable spawn as a passive replica")
	_check(presentation.entity_visuals.has(31), "snapshot recovery should also restore the sword-wave presentation")
	_check(replica.apply_entity_snapshot(_entity_snapshot(77, 21, [{
		"entity_id": 31,
		"entity_kind": "projectile",
		"vfx_id": "sword_wave",
		"position": [18000, 500, 20000],
		"direction": [10000, 0, 0],
	}])), "a newer live entity snapshot should apply")
	var projectile_replica := replica.entity(31) as ReplicaCombatEntity
	var visual_x_before_smoothing := projectile_replica.global_position.x
	_check(projectile_replica.position_target.x > 1.7, "entity snapshots should advance the read-only projectile target")
	_check(projectile_replica.global_position.x < projectile_replica.position_target.x, "a live snapshot should not make the projectile presentation jump directly to its target")
	projectile_replica._process(1.0 / 60.0)
	_check(projectile_replica.global_position.x > visual_x_before_smoothing, "the projectile presentation should advance smoothly between network snapshots")
	_check(replica.entity_spawn_count == 1 and replica.entity_snapshot_apply_count == 2, "snapshot updates must reuse one replica rather than respawn simulation nodes")
	_check(replica.apply_entity_snapshot(_entity_snapshot(77, 22, [])), "a complete empty snapshot should apply")
	_check(replica.entity(31) == null and not presentation.entity_visuals.has(31), "a later complete snapshot must recover a missed destroy")
	_check(replica.apply_authoritative_event(_event_envelope(77, 1, 21, AuthoritativeEvent.ENTITY_SPAWNED, 31)), "an old reliable spawn may be acknowledged after a newer snapshot")
	_check(replica.entity(31) is ReplicaCombatEntity, "a late reliable spawn should still be presented instead of losing a short-lived projectile entirely")
	_check(replica.apply_entity_snapshot(_entity_snapshot(77, 23, [])) and replica.entity(31) == null, "the next complete snapshot should bound and clean a stale late spawn")
	_check(replica.apply_authoritative_event(_event_envelope(77, 2, 24, AuthoritativeEvent.ENTITY_SPAWNED, 32)), "a current reliable spawn should create a replica")
	_check(replica.entity(32) is ReplicaCombatEntity and presentation.entity_visuals.has(32), "reliable spawn should create both passive entity and visual")
	_check(replica.apply_authoritative_event(_event_envelope(77, 3, 25, AuthoritativeEvent.ENTITY_DESTROYED, 32)), "a reliable destroy should apply")
	_check(replica.entity(32) == null and not presentation.entity_visuals.has(32), "reliable destroy should remove entity and presentation")
	var event_id := 4
	for vfx_id in ["bear_throw_knife", "chu_ying_homing_stone", "nailoong_fire_breath", "bear_grapple"]:
		var projectile_id := 40 + event_id
		_check(replica.apply_authoritative_event(_event_envelope(77, event_id, 24 + event_id, AuthoritativeEvent.ENTITY_SPAWNED, projectile_id, vfx_id)), "%s reliable spawn should apply" % vfx_id)
		var visual := presentation.entity_visuals.get(projectile_id) as ProjectileEventVisual
		_check(visual != null and visual.vfx_id == vfx_id and visual.body_visual != null, "%s should build its presentation-only projectile mesh" % vfx_id)
		if vfx_id == "bear_grapple":
			_check(visual.cable_visual != null and visual.source == actor, "grapple presentation should resolve its source actor and build a cable")
		event_id += 1
		_check(replica.apply_authoritative_event(_event_envelope(77, event_id, 24 + event_id, AuthoritativeEvent.ENTITY_DESTROYED, projectile_id, vfx_id)), "%s reliable destroy should apply" % vfx_id)
		_check(replica.entity(projectile_id) == null and not presentation.entity_visuals.has(projectile_id), "%s destroy should clear replica and mesh" % vfx_id)
		event_id += 1
	var shield_actor := CombatActor.new()
	root.add_child(shield_actor)
	shield_actor.setup(SwordShieldDog.create(), 10, "shield")
	shield_actor.battle_id = 10
	replica.register_actor(shield_actor)
	var chu_actor := CombatActor.new()
	root.add_child(chu_actor)
	chu_actor.setup(ChuYing.create(), 11, "chu")
	chu_actor.battle_id = 11
	replica.register_actor(chu_actor)
	var cheems_actor := CombatActor.new()
	root.add_child(cheems_actor)
	cheems_actor.setup(CheemsSamurai.create(), 12, "cheems")
	cheems_actor.battle_id = 12
	replica.register_actor(cheems_actor)
	var bear_actor := CombatActor.new()
	root.add_child(bear_actor)
	bear_actor.setup(BearGryllsJungler.create(), 13, "bear")
	bear_actor.battle_id = 13
	replica.register_actor(bear_actor)
	var nailoong_actor := CombatActor.new()
	root.add_child(nailoong_actor)
	nailoong_actor.setup(Nailoong.create(), 14, "nailoong")
	nailoong_actor.battle_id = 14
	replica.register_actor(nailoong_actor)
	_check(replica.apply_authoritative_event(_world_spawn_envelope(77, event_id, 30, 60, "delayed_attack", {
		"source_id": 10, "vfx_id": "shield_dog_heavy_chop", "position": [1.0, 0.065, 1.0],
		"direction": [1.0, 0.0, 0.0], "remaining": 1.5, "radius": 1.65,
	})), "delayed ground attack spawn should apply")
	var delayed_visual := presentation.entity_visuals.get(60) as WorldEntityEventVisual
	_check(delayed_visual != null and delayed_visual.indicator != null, "delayed attack should build the planted sword from its source actor")
	event_id += 1
	var shockwaves_before := root.find_children("DelayedGroundShockwave", "MeshInstance3D", true, false).size()
	_check(replica.apply_authoritative_event(_world_destroy_envelope(77, event_id, 31, 60, "delayed_attack", "detonated")), "delayed detonation destroy should apply")
	_check(root.find_children("DelayedGroundShockwave", "MeshInstance3D", true, false).size() == shockwaves_before + 1, "detonated destroy should play one presentation-owned shockwave")
	event_id += 1
	_check(replica.apply_authoritative_event(_world_spawn_envelope(77, event_id, 32, 61, "chu_ying_stone", {
		"source_id": 11, "vfx_id": "chu_ying_falling_stone", "attack_id": 902,
		"position": [2.0, 4.27, 2.0], "fall": 0.28, "remaining": 10.0, "flying": false,
	})), "falling stone spawn should apply")
	event_id += 1
	_check(replica.apply_authoritative_event(_world_spawn_envelope(77, event_id, 33, 62, "chu_ying_barrier", {
		"source_id": 11, "vfx_id": "chu_ying_barrier", "position": [0.0, 0.06, 0.0],
		"half_extents": [1.5, 1.0], "remaining": 15.0,
	})), "barrier spawn should apply")
	var barrier_visual := presentation.entity_visuals.get(62) as WorldEntityEventVisual
	var barrier_wall_count := 0
	for wall in get_nodes_in_group("chu_ying_light_walls"):
		if barrier_visual != null and barrier_visual.is_ancestor_of(wall):
			barrier_wall_count += 1
	_check(barrier_visual != null and barrier_wall_count == 4, "barrier replica should build four light walls")
	event_id += 1
	var board_count: int = get_nodes_in_group("chu_ying_board_rectangles").size()
	_check(replica.apply_authoritative_event({
		"match_id": 77,
		"event": AuthoritativeEvent.create(event_id, 34, AuthoritativeEvent.WORLD_EFFECT, 0, {
			"vfx_id": "chu_ying_board", "source_id": 11, "position": [3.0, 0.07, 1.0],
		}).to_packet(),
	}), "board world effect should apply")
	_check(get_nodes_in_group("chu_ying_board_rectangles").size() == board_count + 1, "reliable board event should invoke the same Chu Ying presentation on a replica")
	event_id += 1
	var focus_count := get_nodes_in_group("concentration_rings").size()
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 35, "chu_ying_teleport_charge", 11, {
		"duration": 1.0, "radius": 0.78,
	})), "Chu Ying teleport charge event should apply")
	_check(get_nodes_in_group("concentration_rings").size() > focus_count, "teleport charge should build presentation-owned focus rings")
	event_id += 1
	var teleport_columns := get_nodes_in_group("chu_ying_teleport_columns").size()
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 36, "chu_ying_teleport", 11, {
		"start": [0.0, 0.05, 0.0], "finish": [2.0, 0.05, 1.0],
	})), "Chu Ying teleport endpoint event should apply")
	_check(get_nodes_in_group("chu_ying_teleport_columns").size() == teleport_columns + 2, "teleport event should preserve both authoritative endpoints")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 37, "sword_shield_transform", 10, {"active": true})), "transform event should apply")
	_check(shield_actor.sprite.texture == shield_actor.definition.transformed_sprite_texture and shield_actor.flash_remaining > 0.0, "transform event should immediately switch the replica presentation and flash")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 38, "cheems_dimensional_focus", 12, {
		"ability_id": "ultimate", "radius": 2.0, "duration": 0.5,
	})), "Cheems focus event should apply")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 39, "cheems_dimensional_circle", 12, {
		"ability_id": "ultimate", "duration": 2.5,
	})), "Cheems magic-circle event should apply")
	event_id += 1
	var cut_lines := get_nodes_in_group("dimensional_cut_lines").size()
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 40, "cheems_dimensional_cut", 12, {
		"ability_id": "ultimate", "pulse_index": 1,
	})), "Cheems dimensional pulse event should apply")
	_check(get_nodes_in_group("dimensional_cut_lines").size() == cut_lines + 22, "dimensional pulse should create the presentation-only synchronized cut set")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 41, "bear_poison_mark", 13, {
		"target_id": 10, "duration": 2.0,
	})), "Bear poison mark event should apply")
	_check(shield_actor.get_node_or_null("BearPoisonMark") != null, "poison mark should resolve its stable target actor id")
	for bear_vfx_id in ["bear_poison_burst", "bear_backstab"]:
		event_id += 1
		_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 41 + event_id, bear_vfx_id, 13, {"target_id": 10})), "%s event should apply" % bear_vfx_id)
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 50, "bear_ambush", 13, {
		"ability_id": "ultimate", "start": [-1.0, 0.05, 0.0], "finish": [1.0, 0.05, 0.0],
	})), "Bear ambush endpoints should apply")
	_check(int(presentation.hero_effect_counts_by_vfx.get("bear_ambush", 0)) == 1, "hero presentation should consume each reliable ambush exactly once")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 51, "ability_vfx", 10, {
		"ability_id": "skill_e",
	})), "generic one-shot ability event should apply")
	_check(root.find_children("ShieldBashGhost", "Sprite3D", true, false).size() == 1, "generic event should route normal shield bash through the source presentation")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 51, "ability_vfx", 10, {
		"ability_id": "skill_e", "ability_vfx_id": "swole_slam",
	})), "form-specific one-shot ability event should apply before its state snapshot")
	_check(root.find_children("SwoleSlamShockwave", "MeshInstance3D", true, false).size() == 1, "event vfx id should disambiguate transformed and normal abilities across channels")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 52, "cheems_multi_slash", 12, {
		"ability_id": "skill_w", "duration": 0.4,
	})), "Cheems multi-slash start event should apply")
	for _frame in range(3):
		await process_frame
	_check(root.find_children("MultiSlashVisual", "MeshInstance3D", true, false).size() > 0, "one reliable multi-slash start should drive local repeated slash presentation")
	event_id += 1
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 53, "bear_grapple_pull", 13, {
		"start": [-1.0, 0.05, 0.0], "finish": [1.0, 0.05, 0.0],
	})), "Bear grapple pull endpoint event should apply")
	event_id += 1
	for nail_effect in ["nailoong_takeoff", "nailoong_landing", "nailoong_heal_tick", "nailoong_bounce"]:
		var extra := {"position": [2.0, 0.05, 2.0]}
		if nail_effect == "nailoong_landing":
			extra["radius"] = 1.5
		_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 54 + event_id, nail_effect, 14, extra)), "%s event should apply" % nail_effect)
		event_id += 1
	_check(get_nodes_in_group("nailoong_heal_crosses").size() > 0, "Nailoong heal tick should resolve the actor and authoritative world position")
	_check(int(presentation.hero_effect_counts_by_vfx.get("nailoong_landing", 0)) == 1, "Nailoong landing should be consumed once")
	_check(replica.apply_authoritative_event(_hero_effect_envelope(77, event_id, 70, "sword_shield_block", 10)), "shield block effect should apply")
	_check(replica.apply_entity_snapshot(_entity_snapshot(77, 50, [
		{"entity_id": 61, "entity_kind": "chu_ying_stone", "vfx_id": "chu_ying_falling_stone", "source_id": 11, "attack_id": 902, "position": [30000, 7200, 10000], "fall": 0, "remaining": 90000, "flying": true},
		{"entity_id": 62, "entity_kind": "chu_ying_barrier", "vfx_id": "chu_ying_barrier", "source_id": 11, "position": [0, 600, 0], "half_extents": [15000, 10000], "remaining": 140000},
	])), "world-entity snapshot should update stone and barrier together")
	_check((replica.entity(61) as ReplicaCombatEntity).flying and (replica.entity(61) as ReplicaCombatEntity).global_position.distance_to(Vector3(3.0, 0.72, 1.0)) < 0.001, "stone replica should restore its board-flight phase and position")
	_check((replica.entity(62) as ReplicaCombatEntity).half_extents.is_equal_approx(Vector2(1.5, 1.0)), "barrier replica should restore rectangular extents")
	_check(replica.apply_entity_snapshot(_entity_snapshot(77, 51, [])), "empty world snapshot should apply")
	_check(replica.entity(61) == null and replica.entity(62) == null and not presentation.entity_visuals.has(61) and not presentation.entity_visuals.has(62), "complete snapshot should recover missed world-entity destroys")
	replica.queue_free()
	actor.queue_free()
	shield_actor.queue_free()
	chu_actor.queue_free()
	cheems_actor.queue_free()
	bear_actor.queue_free()
	nailoong_actor.queue_free()
	presentation.queue_free()
	await process_frame
	if failures.is_empty():
		print("Match replica checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _snapshot(match_id: int, tick: int, actor_id: int, position: Vector3, hp: float, defeated: bool, action_id := "") -> Dictionary:
	return {
		"match_id": match_id,
		"server_tick": tick,
		"actor": {
			"actor_id": actor_id,
			"position": [position.x, position.y, position.z],
			"velocity": [0.0, 0.0, 0.0],
			"facing": [-1.0, 0.0],
			"hp": hp,
			"defeated": defeated,
			"current_ability": action_id,
			"ability_phase": "active" if not action_id.is_empty() else "",
			"phase_remaining": 0.1,
			"cooldowns": {},
			"statuses": [],
			"hero_runtime": {},
		}
	}


func _entity_snapshot(match_id: int, tick: int, entities: Array) -> Dictionary:
	return {
		"match_id": match_id,
		"server_tick": tick,
		"last_event_id": 0,
		"entities": entities,
	}


func _event_envelope(match_id: int, event_id: int, tick: int, event_type: StringName, entity_id: int, vfx_id := "sword_wave") -> Dictionary:
	var payload := {"entity_kind": "projectile", "vfx_id": vfx_id}
	if event_type == AuthoritativeEvent.ENTITY_SPAWNED:
		payload["initial_state"] = {
			"source_id": 9,
			"vfx_id": vfx_id,
			"attack_id": event_id,
			"position": [0.0, 0.05, 0.0],
			"direction": [1.0, 0.0, 0.0],
			"radius": 0.16,
			"color": [0.8, 0.9, 1.0, 1.0],
		}
	return {
		"match_id": match_id,
		"event": AuthoritativeEvent.create(event_id, tick, event_type, entity_id, payload).to_packet(),
	}


func _world_spawn_envelope(match_id: int, event_id: int, tick: int, entity_id: int, entity_kind: String, initial_state: Dictionary) -> Dictionary:
	return {
		"match_id": match_id,
		"event": AuthoritativeEvent.create(event_id, tick, AuthoritativeEvent.ENTITY_SPAWNED, entity_id, {
			"entity_kind": entity_kind,
			"initial_state": initial_state,
		}).to_packet(),
	}


func _world_destroy_envelope(match_id: int, event_id: int, tick: int, entity_id: int, entity_kind: String, reason: String) -> Dictionary:
	return {
		"match_id": match_id,
		"event": AuthoritativeEvent.create(event_id, tick, AuthoritativeEvent.ENTITY_DESTROYED, entity_id, {
			"entity_kind": entity_kind,
			"reason": reason,
		}).to_packet(),
	}


func _hero_effect_envelope(match_id: int, event_id: int, tick: int, vfx_id: String, source_id: int, extra: Dictionary = {}) -> Dictionary:
	var payload := extra.duplicate(true)
	payload["vfx_id"] = vfx_id
	payload["source_id"] = source_id
	return {
		"match_id": match_id,
		"event": AuthoritativeEvent.create(event_id, tick, AuthoritativeEvent.HERO_EFFECT, 0, payload).to_packet(),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
