class_name NailoongHeroRuntime
extends HeroRuntime

## Nailoong's authoritative continuous mechanics. State remains on CombatActor
## for the current snapshot contract; this runtime has no autonomous frame loop.

const ROLL_TURN_SPEED := TAU
const CombatEntityFactoryScript = preload("res://src/combat/runtime/combat_entity_factory.gd")
const AttackHitboxScript = preload("res://src/combat/attack_hitbox.gd")


func activate_ability(ability: AbilityDefinition, attack_id: int) -> bool:
	match ability.vfx_id:
		"nailoong_roll":
			actor.nailoong_roll_direction = actor.facing.normalized() if actor.facing.length_squared() > 0.001 else Vector3.RIGHT
			actor._spawn_ability_vfx(ability)
			return true
		"nailoong_fire_breath":
			actor.nailoong_fire_emit_remaining = 0.0
			actor.nailoong_fire_emit_index = 0
			actor._spawn_ability_vfx(ability)
			return true
		"nailoong_leap":
			_start_leap(ability, attack_id)
			return true
		"nailoong_laugh":
			actor.nailoong_regen_tick_remaining = 0.5
			actor.nailoong_regen_ticks_remaining = 10
			actor._spawn_ability_vfx(ability)
			return true
	return false


func update_continuous_ability(delta: float) -> bool:
	if actor.current_ability == null:
		return false
	match actor.current_ability.vfx_id:
		"nailoong_fire_breath":
			if actor.current_ability.maximum_hold_duration > 0.0 and actor.action_elapsed >= actor.current_ability.startup + actor.current_ability.maximum_hold_duration:
				return true
			actor.nailoong_fire_emit_remaining -= delta
			while actor.nailoong_fire_emit_remaining <= 0.0:
				_spawn_fireball(actor.current_ability)
				actor.nailoong_fire_emit_remaining += 0.10
			return true
		"nailoong_roll":
			return true
	return false


func advance(delta: float) -> void:
	_update_regeneration(delta)


func update_pre_motion(delta: float) -> bool:
	if actor.nailoong_leap_remaining <= 0.0:
		return false
	var previous_position := actor.global_position
	actor.nailoong_leap_remaining = maxf(0.0, actor.nailoong_leap_remaining - delta)
	var leap_progress := 1.0 - actor.nailoong_leap_remaining / maxf(actor.nailoong_leap_duration, 0.001)
	actor.global_position = actor.nailoong_leap_start.lerp(actor.nailoong_leap_end, leap_progress)
	actor.global_position.y += sin(leap_progress * PI) * 1.05
	actor.velocity = (actor.global_position - previous_position) / maxf(delta, 0.0001)
	if actor.nailoong_leap_remaining <= 0.0:
		actor.global_position = actor.nailoong_leap_end
		actor.velocity = Vector3.ZERO
		_finish_leap()
	return true


func update_ground_special_motion(delta: float) -> bool:
	if actor.current_ability == null or actor.current_ability.vfx_id != "nailoong_roll" or actor.ability_phase != "active":
		return false
	var desired_roll_direction := _intent_direction()
	if desired_roll_direction.length_squared() > 0.001:
		var turn_angle := actor.nailoong_roll_direction.signed_angle_to(desired_roll_direction, Vector3.UP)
		var turn_step := clampf(turn_angle, -ROLL_TURN_SPEED * delta, ROLL_TURN_SPEED * delta)
		actor.nailoong_roll_direction = (Basis(Vector3.UP, turn_step) * actor.nailoong_roll_direction).normalized()
		actor.facing = actor.nailoong_roll_direction
	var roll_speed := actor.definition.move_speed * 1.65
	var motion := actor.nailoong_roll_direction * roll_speed * delta
	var ray_height := actor.definition.body_radius * 1.05
	var ray_start := actor.global_position + Vector3.UP * ray_height
	var ray_query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + motion + actor.nailoong_roll_direction * actor.definition.body_radius, 1)
	ray_query.collide_with_areas = false
	ray_query.collide_with_bodies = true
	var collision := actor.get_world_3d().direct_space_state.intersect_ray(ray_query)
	if not collision.is_empty() and absf(Vector3(collision["normal"]).y) < 0.65:
		var normal := Vector3(collision["normal"])
		var contact := Vector3(collision["position"])
		actor.global_position.x = contact.x - actor.nailoong_roll_direction.x * (actor.definition.body_radius + 0.025)
		actor.global_position.z = contact.z - actor.nailoong_roll_direction.z * (actor.definition.body_radius + 0.025)
		var bounced := actor.nailoong_roll_direction.bounce(normal)
		bounced.y = 0.0
		if bounced.length_squared() > 0.001:
			actor.nailoong_roll_direction = bounced.normalized()
			actor.facing = actor.nailoong_roll_direction
			if not emit_hero_effect("nailoong_bounce", {"position": _vector_packet(contact)}):
				var vfx := _vfx()
				if vfx != null:
					vfx.spawn_bounce_flash(contact)
	else:
		actor.global_position += motion
	# This ability moves by authored coordinates rather than move_and_slide().
	# Publish its real tangent velocity so replicas can extrapolate smoothly
	# between the 12 Hz authority snapshots.
	actor.velocity = actor.nailoong_roll_direction * roll_speed
	return true


func cancel_special_for_command() -> bool:
	if actor.current_ability == null or actor.current_ability.vfx_id != "nailoong_roll":
		return false
	actor._cancel_current_ability()
	return true


func on_defeated() -> void:
	actor.nailoong_leap_remaining = 0.0
	actor.nailoong_fire_emit_remaining = 0.0
	actor.nailoong_regen_ticks_remaining = 0


func reset() -> void:
	actor.nailoong_roll_direction = Vector3.RIGHT
	actor.nailoong_fire_emit_remaining = 0.0
	actor.nailoong_fire_emit_index = 0
	actor.nailoong_leap_remaining = 0.0
	actor.nailoong_leap_duration = 0.0
	actor.nailoong_leap_start = Vector3.ZERO
	actor.nailoong_leap_end = Vector3.ZERO
	actor.nailoong_leap_ability = null
	actor.nailoong_leap_attack_id = 0
	actor.nailoong_regen_tick_remaining = 0.0
	actor.nailoong_regen_ticks_remaining = 0


func runtime_snapshot() -> Dictionary:
	return {
		"roll_direction": [_quantize(actor.nailoong_roll_direction.x), _quantize(actor.nailoong_roll_direction.y), _quantize(actor.nailoong_roll_direction.z)],
		"fire_index": actor.nailoong_fire_emit_index,
		"fire_timer": _quantize(actor.nailoong_fire_emit_remaining),
		"leap_remaining": _quantize(actor.nailoong_leap_remaining),
		"leap_end": [_quantize(actor.nailoong_leap_end.x), _quantize(actor.nailoong_leap_end.y), _quantize(actor.nailoong_leap_end.z)],
		"regen_ticks": actor.nailoong_regen_ticks_remaining,
		"regen_timer": _quantize(actor.nailoong_regen_tick_remaining),
	}


func apply_runtime_snapshot(snapshot: Dictionary) -> void:
	var roll_packet = snapshot.get("roll_direction", [])
	if roll_packet is Array and (roll_packet as Array).size() >= 3:
		actor.nailoong_roll_direction = Vector3(_dequantize((roll_packet as Array)[0]), _dequantize((roll_packet as Array)[1]), _dequantize((roll_packet as Array)[2]))
	actor.nailoong_fire_emit_index = maxi(0, int(snapshot.get("fire_index", actor.nailoong_fire_emit_index)))
	actor.nailoong_fire_emit_remaining = maxf(0.0, _dequantize(snapshot.get("fire_timer", _quantize(actor.nailoong_fire_emit_remaining))))
	actor.nailoong_leap_remaining = maxf(0.0, _dequantize(snapshot.get("leap_remaining", _quantize(actor.nailoong_leap_remaining))))
	var leap_packet = snapshot.get("leap_end", [])
	if leap_packet is Array and (leap_packet as Array).size() >= 3:
		actor.nailoong_leap_end = Vector3(_dequantize((leap_packet as Array)[0]), _dequantize((leap_packet as Array)[1]), _dequantize((leap_packet as Array)[2]))
	actor.nailoong_regen_ticks_remaining = maxi(0, int(snapshot.get("regen_ticks", actor.nailoong_regen_ticks_remaining)))
	actor.nailoong_regen_tick_remaining = maxf(0.0, _dequantize(snapshot.get("regen_timer", _quantize(actor.nailoong_regen_tick_remaining))))


func _spawn_fireball(ability: AbilityDefinition) -> void:
	var fan_offsets := [-22.0, -11.0, 0.0, 11.0, 22.0, 6.0, -16.0, 16.0, -6.0, 0.0]
	var angle := deg_to_rad(float(fan_offsets[actor.nailoong_fire_emit_index % fan_offsets.size()]))
	actor.nailoong_fire_emit_index += 1
	var shot_direction := Basis(Vector3.UP, angle) * actor.facing
	shot_direction.y = 0.0
	shot_direction = shot_direction.normalized()
	var attack_id := CombatActor.next_attack_id
	CombatActor.next_attack_id += 1
	CombatEntityFactoryScript.spawn_projectile(
		actor.match_authority(), actor.get_parent(), actor, ability, shot_direction, attack_id,
		actor.global_position + shot_direction * 0.52 + Vector3.UP * ability.projectile_height
	)


func _start_leap(ability: AbilityDefinition, attack_id: int) -> void:
	var direction := actor.pending_ability_target - actor.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = actor.facing
	var distance := minf(direction.length(), 3.0)
	direction = direction.normalized()
	actor.facing = direction
	actor.nailoong_leap_start = actor.global_position
	actor.nailoong_leap_end = _safe_leap_endpoint(actor.global_position + direction * distance)
	actor.nailoong_leap_end.y = actor.global_position.y
	actor.nailoong_leap_duration = maxf(ability.active, 0.32)
	actor.nailoong_leap_remaining = actor.nailoong_leap_duration
	actor.nailoong_leap_ability = ability
	actor.nailoong_leap_attack_id = attack_id
	if not emit_hero_effect("nailoong_takeoff", {"position": _vector_packet(actor.nailoong_leap_start)}):
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_takeoff_ring()


func _safe_leap_endpoint(preferred: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius = actor.definition.body_radius * 0.88
	var direction := preferred - actor.global_position
	direction.y = 0.0
	for step in range(13):
		var ratio := 1.0 - float(step) / 12.0
		var candidate := actor.global_position + direction * ratio
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * actor.definition.body_radius)
		query.collision_mask = 1
		if actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return _apply_movement_confinements(candidate)
	return _apply_movement_confinements(actor.global_position)


func _apply_movement_confinements(preferred: Vector3) -> Vector3:
	var result := preferred
	for node in actor.get_tree().get_nodes_in_group("movement_confinements"):
		if node != null and is_instance_valid(node) and node.has_method("confined_destination"):
			result = node.call("confined_destination", actor, result) as Vector3
	return result


func _finish_leap() -> void:
	if actor.nailoong_leap_ability == null:
		return
	var hitbox := AttackHitboxScript.new() as AttackHitbox
	actor.add_child(hitbox)
	hitbox.configure(actor, actor.nailoong_leap_ability, actor.nailoong_leap_attack_id)
	if not emit_hero_effect("nailoong_landing", {
		"position": _vector_packet(actor.global_position),
		"radius": actor.nailoong_leap_ability.hitbox_radius,
	}):
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_landing_wave(actor.nailoong_leap_ability.hitbox_radius)
	actor.nailoong_leap_ability = null
	actor.nailoong_leap_attack_id = 0


func _update_regeneration(delta: float) -> void:
	if actor.nailoong_regen_ticks_remaining <= 0:
		return
	if actor.is_defeated:
		actor.nailoong_regen_ticks_remaining = 0
		return
	actor.nailoong_regen_tick_remaining -= delta
	while actor.nailoong_regen_tick_remaining <= 0.0 and actor.nailoong_regen_ticks_remaining > 0:
		actor.heal(12.0, actor.battle_id)
		actor.nailoong_regen_ticks_remaining -= 1
		actor.nailoong_regen_tick_remaining += 0.5
		if not emit_hero_effect("nailoong_heal_tick", {"position": _vector_packet(actor.global_position)}):
			var vfx := _vfx()
			if vfx != null:
				vfx.spawn_heal_tick()


func _intent_direction() -> Vector3:
	var direction := Vector3(actor.move_intent.x, 0.0, actor.move_intent.y)
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO


func _quantize(value: float) -> int:
	return roundi(value * 10000.0)


func _dequantize(value) -> float:
	return float(value) / 10000.0


func _vfx() -> NailoongVfx:
	return actor.actor_presentation.hero_vfx as NailoongVfx


func _vector_packet(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
