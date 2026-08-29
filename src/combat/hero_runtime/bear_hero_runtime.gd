class_name BearHeroRuntime
extends HeroRuntime

## Bear-specific authoritative mechanics. Visual effects are emitted through
## the presentation-owned BearVfx component.


func select_ability(ability_id: String, fallback: AbilityDefinition) -> AbilityDefinition:
	if ability_id != "basic":
		return fallback
	var nearest: CombatActor
	var best := fallback.auto_target_radius * fallback.auto_target_radius
	var pointed: CombatActor
	var pointed_distance := INF
	for value in actor.get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate == actor or candidate.team == actor.team or candidate.is_defeated or not candidate.is_visible_to(actor.team):
				continue
			var offset := candidate.global_position - actor.global_position
			offset.y = 0.0
			var distance := offset.length_squared()
			if distance <= best:
				nearest = candidate
				best = distance
			var point_offset := candidate.global_position - actor.pending_ability_target
			point_offset.y = 0.0
			var point_distance := point_offset.length_squared()
			var point_radius := candidate.definition.body_radius + 0.35
			if distance <= fallback.auto_target_radius * fallback.auto_target_radius and point_distance <= point_radius * point_radius and point_distance < pointed_distance:
				pointed = candidate
				pointed_distance = point_distance
	if pointed != null:
		nearest = pointed
		var pointed_offset := pointed.global_position - actor.global_position
		pointed_offset.y = 0.0
		best = pointed_offset.length_squared()
	var melee = actor.definition.ability_variants.get("basic_melee")
	if nearest != null and melee is AbilityDefinition:
		var melee_reach := (melee as AbilityDefinition).hitbox_radius + nearest.definition.body_radius * 0.86
		if sqrt(best) <= melee_reach:
			return melee as AbilityDefinition
	return fallback


func prepare_ability(ability_id: String, ability: AbilityDefinition) -> bool:
	if ability_id != "ultimate":
		return true
	actor.bear_ultimate_target = _find_ultimate_target(ability.target_required_range)
	return actor.bear_ultimate_target != null


func activate_ability(ability: AbilityDefinition, attack_id: int) -> bool:
	if ability.vfx_id == "bear_stealth":
		actor.apply_status(CombatStatuses.stealth(15.0), actor.battle_id)
		actor._spawn_ability_vfx(ability)
		return true
	if ability.vfx_id == "bear_ambush":
		_activate_ambush(ability, attack_id)
		return true
	return false


func advance(delta: float) -> void:
	actor.bear_grapple_pull_remaining = maxf(0.0, actor.bear_grapple_pull_remaining - delta)


func reset() -> void:
	actor.bear_ultimate_target = null
	actor.bear_grapple_pull_remaining = 0.0


func on_delayed_damage_queued(target: CombatActor, ability: AbilityDefinition) -> void:
	if emit_hero_effect("bear_poison_mark", {
		"target_id": target.battle_id,
		"duration": ability.target_delayed_damage_delay,
	}):
		return
	var vfx := _vfx()
	if vfx != null:
		vfx.spawn_poison_mark(target, ability.target_delayed_damage_delay)


func on_delayed_damage_resolved(target: CombatActor, _ability: AbilityDefinition) -> void:
	if emit_hero_effect("bear_poison_burst", {"target_id": target.battle_id}):
		return
	var vfx := _vfx()
	if vfx != null:
		vfx.spawn_poison_burst(target)


func modify_outgoing_damage(target: CombatActor, _ability: AbilityDefinition, base_damage: float) -> float:
	if base_damage <= 0.0 or target == null:
		return base_damage
	var to_source := actor.global_position - target.global_position
	to_source.y = 0.0
	if to_source.length_squared() <= 0.001:
		return base_damage
	var target_forward := Vector3(target.facing.x, 0.0, target.facing.z).normalized()
	if target_forward.length_squared() > 0.001 and target_forward.dot(to_source.normalized()) <= -0.5:
		if not emit_hero_effect("bear_backstab", {"target_id": target.battle_id}):
			var vfx := _vfx()
			if vfx != null:
				vfx.spawn_backstab_flash(target)
		return base_damage * 2.0
	return base_damage


func on_killed_actor(_target: CombatActor, ability: AbilityDefinition) -> void:
	if actor.is_defeated:
		return
	actor.hp = minf(actor.definition.max_hp, actor.hp + 30.0)
	if ability != null and ability.ability_id == "ultimate":
		actor.cooldowns["ultimate"] = 0.0
	actor.resource_changed.emit(actor)


func begin_grapple_pull(endpoint: Vector3) -> void:
	if actor.is_defeated:
		return
	actor.dash_start = actor.global_position
	actor.dash_end = Vector3(endpoint.x, actor.global_position.y, endpoint.z)
	var distance := actor.dash_start.distance_to(actor.dash_end)
	if distance <= 0.05:
		return
	actor.dash_duration = clampf(distance / 10.5, 0.10, 0.48)
	actor.dash_remaining = actor.dash_duration
	actor.dash_phasing = true
	actor.bear_grapple_pull_remaining = actor.dash_duration
	if actor.status_controller.has_tag("stealth"):
		actor.status_controller.remove("bear_stealth")
	if not emit_hero_effect("bear_grapple_pull", {
		"start": _vector_packet(actor.dash_start),
		"finish": _vector_packet(actor.dash_end),
	}):
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_pull_streaks(actor.dash_start, actor.dash_end)


func _find_ultimate_target(max_range: float) -> CombatActor:
	var nearest: CombatActor
	var nearest_distance := max_range * max_range
	var pointed: CombatActor
	var pointed_distance := 1.10 * 1.10
	for value in actor.get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate == actor or candidate.team == actor.team or candidate.is_defeated or not candidate.is_targetable() or not candidate.is_visible_to(actor.team):
				continue
			var source_distance := actor.global_position.distance_squared_to(candidate.global_position)
			if source_distance > max_range * max_range:
				continue
			var point_distance := actor.pending_ability_target.distance_squared_to(candidate.global_position)
			if point_distance <= pointed_distance:
				pointed = candidate
				pointed_distance = point_distance
			if source_distance <= nearest_distance:
				nearest = candidate
				nearest_distance = source_distance
	return pointed if pointed != null else nearest


func _activate_ambush(ability: AbilityDefinition, attack_id: int) -> void:
	var target := actor.bear_ultimate_target
	actor.bear_ultimate_target = null
	if target == null or not is_instance_valid(target) or target.is_defeated or not target.is_targetable():
		return
	var old_position := actor.global_position
	var behind := Vector3(target.facing.x, 0.0, target.facing.z).normalized()
	if behind.length_squared() <= 0.001:
		behind = -actor.facing
	var landing := target.global_position - behind * (target.definition.body_radius + actor.definition.body_radius + 0.16)
	landing.y = actor.global_position.y
	actor.global_position = _safe_ambush_position(landing, target.global_position)
	var to_target := target.global_position - actor.global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.001:
		actor.facing = to_target.normalized()
	if not emit_hero_effect("bear_ambush", {
		"ability_id": ability.ability_id,
		"start": _vector_packet(old_position),
		"finish": _vector_packet(actor.global_position),
	}):
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_afterimage(old_position, ability)
			vfx.spawn_teleport_trail(old_position, actor.global_position, ability)
			vfx.spawn_afterimage(actor.global_position, ability)
	var hp_before := target.hp
	if target.receive_hit(actor, ability, actor.facing, attack_id, ability.damage):
		actor.on_ability_hit(ability, minf(hp_before, ability.damage))


func _safe_ambush_position(preferred: Vector3, target_position: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius = actor.definition.body_radius * 0.88
	for offset_value in [Vector3.ZERO, Vector3(0.42, 0.0, 0.0), Vector3(-0.42, 0.0, 0.0), Vector3(0.0, 0.0, 0.42), Vector3(0.0, 0.0, -0.42)]:
		var candidate: Vector3 = preferred + Vector3(offset_value)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * actor.definition.body_radius)
		query.collision_mask = 1
		if actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	var fallback := target_position - (target_position - actor.global_position).normalized() * 0.75
	fallback.y = actor.global_position.y
	return fallback


func _vfx() -> BearVfx:
	return actor.actor_presentation.hero_vfx as BearVfx


func _vector_packet(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
