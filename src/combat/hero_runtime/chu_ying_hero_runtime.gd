class_name ChuYingHeroRuntime
extends HeroRuntime

## Chu Ying's authoritative charge and ability orchestration. Stones and the
## barrier remain independent deterministic combat entities so they can gain
## stable entity IDs without changing this runtime's public contract.

const MAX_Q_CHARGES := 3
const Q_RECHARGE_SECONDS := 5.0
const CombatEntityFactoryScript = preload("res://src/combat/runtime/combat_entity_factory.gd")

var barrier_cast_origin := Vector3.ZERO
var barrier_cast_endpoint := Vector3.ZERO
var barrier_cast_geometry_ready := false


func initialize() -> void:
	_reset_charges()


func has_special_resource(ability_id: String) -> bool:
	return ability_id != "skill_q" or actor.chu_ying_q_charges > 0


func commit_ability(ability_id: String, _ability: AbilityDefinition, bypass_cost: bool) -> void:
	actor.current_attack_damage_multiplier = 1.0
	if ability_id != "skill_q" or bypass_cost:
		return
	actor.chu_ying_q_charges = maxi(0, actor.chu_ying_q_charges - 1)
	actor.energy = float(actor.chu_ying_q_charges)
	if actor.chu_ying_q_recharge_remaining <= 0.0:
		actor.chu_ying_q_recharge_remaining = Q_RECHARGE_SECONDS


func before_startup_effects(ability: AbilityDefinition) -> void:
	if ability.vfx_id == "chu_ying_barrier":
		# Freeze the two selected corners when the cast begins. The 0.5-second
		# windup must not silently move the rectangle if the authority corrects
		# or otherwise changes the actor position before activation.
		barrier_cast_origin = Vector3(actor.global_position.x, 0.0, actor.global_position.z)
		barrier_cast_endpoint = _clamped_ability_point(ability.target_required_range)
		barrier_cast_geometry_ready = true
	if ability.vfx_id == "chu_ying_teleport":
		if emit_hero_effect("chu_ying_teleport_charge", {
			"duration": ability.startup,
			"radius": 0.78,
		}):
			return
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_teleport_charge(ability.startup)
		actor.actor_presentation.spawn_concentration_rings(0.78, ability.startup, "ChuYingTeleportFocus")


func activate_ability(ability: AbilityDefinition, attack_id: int) -> bool:
	match ability.vfx_id:
		"chu_ying_homing_stone":
			_activate_basic(ability, attack_id)
			return true
		"chu_ying_falling_stone":
			_activate_falling_stone(ability, attack_id)
			return true
		"chu_ying_board":
			_activate_board(ability, attack_id)
			return true
		"chu_ying_teleport":
			_activate_teleport(ability)
			return true
		"chu_ying_barrier":
			_activate_barrier(ability, attack_id)
			return true
	return false


func advance(delta: float) -> void:
	if actor.chu_ying_q_charges >= MAX_Q_CHARGES:
		return
	actor.chu_ying_q_recharge_remaining -= delta
	while actor.chu_ying_q_recharge_remaining <= 0.0 and actor.chu_ying_q_charges < MAX_Q_CHARGES:
		actor.chu_ying_q_charges += 1
		actor.energy = float(actor.chu_ying_q_charges)
		if actor.chu_ying_q_charges < MAX_Q_CHARGES:
			actor.chu_ying_q_recharge_remaining += Q_RECHARGE_SECONDS
		else:
			actor.chu_ying_q_recharge_remaining = 0.0
		actor.resource_changed.emit(actor)


func reset() -> void:
	_reset_charges()
	barrier_cast_geometry_ready = false


func runtime_snapshot() -> Dictionary:
	return {
		"q_charges": actor.chu_ying_q_charges,
		"q_recharge": roundi(actor.chu_ying_q_recharge_remaining * 10000.0),
	}


func apply_runtime_snapshot(snapshot: Dictionary) -> void:
	actor.chu_ying_q_charges = clampi(int(snapshot.get("q_charges", actor.chu_ying_q_charges)), 0, MAX_Q_CHARGES)
	actor.chu_ying_q_recharge_remaining = maxf(0.0, float(snapshot.get("q_recharge", roundi(actor.chu_ying_q_recharge_remaining * 10000.0))) / 10000.0)
	actor.energy = float(actor.chu_ying_q_charges)


func _activate_basic(ability: AbilityDefinition, attack_id: int) -> void:
	var target := _find_enemy_near_ability_point(ability.target_required_range)
	if target == null:
		return
	var direction := target.global_position - actor.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		actor.facing = direction.normalized()
	CombatEntityFactoryScript.spawn_projectile(
		actor.match_authority(), actor.get_parent(), actor, ability, actor.facing, attack_id,
		actor.global_position + actor.facing * 0.48 + Vector3.UP * ability.projectile_height, target
	)


func _activate_falling_stone(ability: AbilityDefinition, attack_id: int) -> void:
	var landing_position := _clamped_ability_point(ability.target_required_range)
	CombatEntityFactoryScript.spawn_chu_ying_stone(actor.match_authority(), actor.get_parent(), actor, ability, attack_id, landing_position)


func _activate_board(ability: AbilityDefinition, attack_id: int) -> void:
	var board_position := _clamped_ability_point(ability.target_required_range)
	actor._damage_circle_at(board_position, ability.hitbox_radius, ability, attack_id)
	var authority := actor.match_authority()
	if authority != null:
		authority.emit_authoritative_event(AuthoritativeEvent.WORLD_EFFECT, 0, {
			"vfx_id": "chu_ying_board",
			"source_id": actor.battle_id,
			"position": [board_position.x, board_position.y, board_position.z],
		})
	else:
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_board(board_position)
	for value in actor.get_tree().get_nodes_in_group("chu_ying_stones"):
		if value is ChuYingStone:
			var stone := value as ChuYingStone
			if stone.source != null and stone.source.team == actor.team and stone.can_be_pulled() and stone.global_position.distance_squared_to(board_position) <= 25.0:
				stone.fly_to(board_position, ability)


func _activate_teleport(ability: AbilityDefinition) -> void:
	var old_position := actor.global_position
	var destination := _safe_teleport_endpoint(_clamped_ability_point(ability.target_required_range))
	actor.global_position = destination
	actor.velocity = Vector3.ZERO
	if not emit_hero_effect("chu_ying_teleport", {
		"start": _vector_packet(old_position),
		"finish": _vector_packet(destination),
	}):
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_teleport_ghost(old_position)
			vfx.spawn_teleport_ghost(destination)


func _activate_barrier(ability: AbilityDefinition, attack_id: int) -> void:
	var origin := barrier_cast_origin if barrier_cast_geometry_ready else Vector3(actor.global_position.x, 0.0, actor.global_position.z)
	var endpoint := barrier_cast_endpoint if barrier_cast_geometry_ready else _clamped_ability_point(ability.target_required_range)
	barrier_cast_geometry_ready = false
	var center := (origin + endpoint) * 0.5
	var half_extents := Vector2(
		maxf(absf(endpoint.x - origin.x) * 0.5, 0.5),
		maxf(absf(endpoint.z - origin.z) * 0.5, 0.5)
	)
	actor._damage_box_at(center, half_extents, ability, attack_id)
	CombatEntityFactoryScript.spawn_chu_ying_barrier(actor.match_authority(), actor.get_parent(), actor, ability, attack_id, center, half_extents)


func _find_enemy_near_ability_point(max_range: float) -> CombatActor:
	var pointed: CombatActor
	var pointed_distance := 1.0
	var nearest: CombatActor
	var nearest_distance := max_range * max_range
	for value in actor.get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate == actor or candidate.team == actor.team or candidate.is_defeated or not candidate.is_targetable() or not candidate.is_visible_to(actor.team):
				continue
			var source_offset := candidate.global_position - actor.global_position
			source_offset.y = 0.0
			var source_distance := source_offset.length_squared()
			if source_distance > max_range * max_range:
				continue
			var point_offset := candidate.global_position - actor.pending_ability_target
			point_offset.y = 0.0
			var point_distance := point_offset.length_squared()
			if point_distance <= pointed_distance:
				pointed = candidate
				pointed_distance = point_distance
			if source_distance <= nearest_distance:
				nearest = candidate
				nearest_distance = source_distance
	return pointed if pointed != null else nearest


func _clamped_ability_point(max_range: float) -> Vector3:
	var offset := actor.pending_ability_target - actor.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = actor.facing * minf(0.8, max_range)
	elif offset.length() > max_range:
		offset = offset.normalized() * max_range
	return Vector3(actor.global_position.x + offset.x, 0.07, actor.global_position.z + offset.z)


func _safe_teleport_endpoint(preferred: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius = actor.definition.body_radius * 0.88
	var offset := preferred - actor.global_position
	offset.y = 0.0
	for step in range(21):
		var ratio := 1.0 - float(step) / 20.0
		var candidate := actor.global_position + offset * ratio
		candidate.y = actor.global_position.y
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * actor.definition.body_radius)
		query.collision_mask = 1
		var ground_query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 2.2, candidate + Vector3.DOWN * 0.8, 1)
		ground_query.collide_with_areas = false
		ground_query.collide_with_bodies = true
		var has_ground := not actor.get_world_3d().direct_space_state.intersect_ray(ground_query).is_empty()
		if has_ground and actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return actor.global_position


func _reset_charges() -> void:
	actor.chu_ying_q_charges = MAX_Q_CHARGES
	actor.chu_ying_q_recharge_remaining = 0.0
	actor.energy = float(MAX_Q_CHARGES)


func _vfx() -> ChuYingVfx:
	return actor.actor_presentation.hero_vfx as ChuYingVfx


func _vector_packet(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
