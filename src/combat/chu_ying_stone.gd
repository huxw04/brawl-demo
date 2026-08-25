class_name ChuYingStone
extends Node3D

var source: CombatActor
var landing_ability: AbilityDefinition
var travel_ability: AbilityDefinition
var unit_id := 0
var ground_position := Vector3.ZERO
var fall_remaining := 0.28
var ground_remaining := 10.0
var flying := false
var flight_destination := Vector3.ZERO
var hit_targets: Dictionary = {}
var visual: MeshInstance3D


func configure(p_source: CombatActor, p_ability: AbilityDefinition, p_position: Vector3, p_unit_id: int) -> void:
	source = p_source
	landing_ability = p_ability
	unit_id = p_unit_id
	ground_position = Vector3(p_position.x, 0.07, p_position.z)
	global_position = ground_position + Vector3.UP * 4.2
	add_to_group("chu_ying_stones")
	add_to_group("deterministic_combat_units")
	add_to_group("transient_combat_vfx")
	_create_visual()


func _create_visual() -> void:
	visual = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.14
	mesh.bottom_radius = 0.14
	mesh.height = 0.055
	mesh.radial_segments = 32
	mesh.material = _material(Color("15181d") if unit_id % 2 == 0 else Color("f2f3ef"))
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual)


func _physics_process(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	if flying:
		_update_flight(delta)
		return
	if fall_remaining > 0.0:
		fall_remaining = maxf(0.0, fall_remaining - delta)
		var progress := 1.0 - fall_remaining / 0.28
		global_position = ground_position + Vector3.UP * lerpf(4.2, 0.0, progress * progress)
		visual.rotation.y += delta * 9.0
		if fall_remaining <= 0.0:
			global_position = ground_position
			_land()
		return
	ground_remaining -= delta
	if ground_remaining <= 0.0:
		queue_free()


func can_be_pulled() -> bool:
	return not flying and fall_remaining <= 0.0


func fly_to(board_position: Vector3, ability: AbilityDefinition) -> void:
	if not can_be_pulled():
		return
	flying = true
	travel_ability = ability
	flight_destination = Vector3(board_position.x, 0.72, board_position.z)
	global_position.y = 0.72
	hit_targets.clear()


func _update_flight(delta: float) -> void:
	var previous := global_position
	var next := global_position.move_toward(flight_destination, 10.5 * delta)
	_damage_segment(previous, next)
	global_position = next
	visual.rotation.y += delta * 18.0
	visual.rotation.z += delta * 13.0
	if global_position.distance_squared_to(flight_destination) <= 0.0025:
		queue_free()


func _land() -> void:
	_damage_circle(landing_ability.hitbox_radius, landing_ability)
	var ring := MeshInstance3D.new()
	ring.top_level = true
	ring.add_to_group("transient_combat_vfx")
	get_parent().add_child(ring)
	ring.global_position = ground_position
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.16
	mesh.outer_radius = landing_ability.hitbox_radius
	mesh.rings = 28
	mesh.ring_segments = 6
	mesh.material = _material(Color(0.86, 0.91, 1.0, 0.58))
	ring.mesh = mesh
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.35, 0.16)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.18)
	tween.tween_callback(ring.queue_free)


func _damage_circle(radius: float, ability: AbilityDefinition) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(global_position.x, 0.9, global_position.z))
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider = result.get("collider")
		var target = collider.get_meta("combat_actor", null) if collider is Area3D else null
		if target is CombatActor and target != source and target.team != source.team:
			var combat_target := target as CombatActor
			var hp_before: float = combat_target.hp
			var direction: Vector3 = combat_target.global_position - global_position
			direction.y = 0.0
			if combat_target.receive_hit(source, ability, direction.normalized(), unit_id, ability.damage):
				source.on_ability_hit(ability, minf(hp_before, ability.damage))


func _damage_segment(start: Vector3, finish: Vector3) -> void:
	if travel_ability == null:
		return
	var excluded: Array[RID] = []
	for _index in range(16):
		var query := PhysicsRayQueryParameters3D.create(start, finish, 2)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.exclude = excluded
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			break
		var collider = result.get("collider")
		if collider is CollisionObject3D:
			excluded.append((collider as CollisionObject3D).get_rid())
		var target = collider.get_meta("combat_actor", null) if collider is Area3D else null
		if not target is CombatActor or target == source or target.team == source.team or hit_targets.has(target.get_instance_id()):
			continue
		var combat_target := target as CombatActor
		hit_targets[combat_target.get_instance_id()] = true
		var hp_before: float = combat_target.hp
		var direction: Vector3 = finish - start
		direction.y = 0.0
		if combat_target.receive_hit(source, travel_ability, direction.normalized(), unit_id, travel_ability.damage):
			source.on_ability_hit(travel_ability, minf(hp_before, travel_ability.damage))


func combat_snapshot() -> Dictionary:
	return {
		"id": unit_id,
		"type": "chu_ying_stone",
		"position": [roundi(global_position.x * 10000.0), roundi(global_position.y * 10000.0), roundi(global_position.z * 10000.0)],
		"fall": roundi(fall_remaining * 10000.0),
		"remaining": roundi(ground_remaining * 10000.0),
		"flying": flying,
	}


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.25
	return material
