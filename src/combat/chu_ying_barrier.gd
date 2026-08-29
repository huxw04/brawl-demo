class_name ChuYingBarrier
extends Node3D

var source: CombatActor
var entity_id := 0
var unit_id := 0
var half_extents := Vector2.ONE
var remaining := 15.0
var trapped: Array[CombatActor] = []
var last_contained_positions: Dictionary = {}


func configure(p_source: CombatActor, center: Vector3, p_half_extents: Vector2, p_unit_id: int) -> void:
	source = p_source
	unit_id = p_unit_id
	half_extents = Vector2(maxf(p_half_extents.x, 0.5), maxf(p_half_extents.y, 0.5))
	global_position = Vector3(center.x, 0.06, center.z)
	# Enforce after actors, command motors, AI and knockback have updated this tick.
	process_physics_priority = 1000
	add_to_group("deterministic_combat_units")
	add_to_group("movement_confinements")
	add_to_group("transient_combat_vfx")
	for value in get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var actor := value as CombatActor
			var offset := actor.global_position - global_position
			if actor != source and actor.team != source.team and not actor.is_defeated and absf(offset.x) <= half_extents.x and absf(offset.z) <= half_extents.y:
				trapped.append(actor)
				var body_margin := actor.definition.body_radius * 0.55
				last_contained_positions[actor.battle_id] = Vector2(
					clampf(actor.global_position.x, global_position.x - half_extents.x + body_margin, global_position.x + half_extents.x - body_margin),
					clampf(actor.global_position.z, global_position.z - half_extents.y + body_margin, global_position.z + half_extents.y - body_margin)
				)
	if get_tree().get_first_node_in_group("authority_event_presentation") == null:
		_create_visual()


func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	for actor in trapped:
		if actor == null or not is_instance_valid(actor) or actor.is_defeated:
			continue
		_constrain_actor(actor)


func _constrain_actor(actor: CombatActor) -> void:
	var body_margin := actor.definition.body_radius * 0.55
	var allowed_x := maxf(0.05, half_extents.x - body_margin)
	var allowed_z := maxf(0.05, half_extents.y - body_margin)
	var local_x := actor.global_position.x - global_position.x
	var local_z := actor.global_position.z - global_position.z
	var clamped_x := clampf(local_x, -allowed_x, allowed_x)
	var clamped_z := clampf(local_z, -allowed_z, allowed_z)
	var outside := not is_equal_approx(local_x, clamped_x) or not is_equal_approx(local_z, clamped_z)
	if not outside:
		last_contained_positions[actor.battle_id] = Vector2(actor.global_position.x, actor.global_position.z)
		return
	# Returning to the last valid interior point is robust when an arena wall
	# overlaps the visual boundary. Clamping directly onto that wall allowed the
	# next CharacterBody collision recovery to push the actor outside again.
	var fallback: Vector2 = last_contained_positions.get(
		actor.battle_id,
		Vector2(global_position.x + clamped_x, global_position.z + clamped_z),
	)
	actor.global_position.x = clampf(fallback.x, global_position.x - allowed_x, global_position.x + allowed_x)
	actor.global_position.z = clampf(fallback.y, global_position.z - allowed_z, global_position.z + allowed_z)
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0
	actor.knockback_velocity.x = 0.0
	actor.knockback_velocity.z = 0.0


func confined_destination(actor: CombatActor, preferred: Vector3) -> Vector3:
	if actor == null or not trapped.has(actor):
		return preferred
	var body_margin := actor.definition.body_radius * 0.55
	var allowed_x := maxf(0.05, half_extents.x - body_margin)
	var allowed_z := maxf(0.05, half_extents.y - body_margin)
	var local_x := preferred.x - global_position.x
	var local_z := preferred.z - global_position.z
	if absf(local_x) <= allowed_x and absf(local_z) <= allowed_z:
		return preferred
	var last_valid: Vector2 = last_contained_positions.get(
		actor.battle_id,
		Vector2(
			global_position.x + clampf(local_x, -allowed_x, allowed_x),
			global_position.z + clampf(local_z, -allowed_z, allowed_z),
		),
	)
	return Vector3(last_valid.x, preferred.y, last_valid.y)


func _create_visual() -> void:
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(half_extents.x * 2.0, 0.025, half_extents.y * 2.0)
	floor_mesh.material = _material(Color(0.45, 0.66, 0.92, 0.10))
	floor.mesh = floor_mesh
	add_child(floor)
	_add_edge(Vector3(0.0, 0.05, -half_extents.y), Vector3(half_extents.x * 2.0, 0.08, 0.06))
	_add_edge(Vector3(0.0, 0.05, half_extents.y), Vector3(half_extents.x * 2.0, 0.08, 0.06))
	_add_edge(Vector3(-half_extents.x, 0.05, 0.0), Vector3(0.06, 0.08, half_extents.y * 2.0))
	_add_edge(Vector3(half_extents.x, 0.05, 0.0), Vector3(0.06, 0.08, half_extents.y * 2.0))
	var wall_height := maxf(0.65, maxf(half_extents.x * 2.0, half_extents.y * 2.0) * 0.55)
	_add_light_wall(Vector3(0.0, wall_height * 0.5, -half_extents.y), Vector2(half_extents.x * 2.0, wall_height), 0.0)
	_add_light_wall(Vector3(0.0, wall_height * 0.5, half_extents.y), Vector2(half_extents.x * 2.0, wall_height), 0.0)
	_add_light_wall(Vector3(-half_extents.x, wall_height * 0.5, 0.0), Vector2(half_extents.y * 2.0, wall_height), PI * 0.5)
	_add_light_wall(Vector3(half_extents.x, wall_height * 0.5, 0.0), Vector2(half_extents.y * 2.0, wall_height), PI * 0.5)


func _add_edge(position: Vector3, size: Vector3) -> void:
	var edge := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(Color(0.76, 0.88, 1.0, 0.90))
	edge.mesh = mesh
	edge.position = position
	add_child(edge)


func _add_light_wall(position: Vector3, size: Vector2, yaw: float) -> void:
	var wall := MeshInstance3D.new()
	wall.name = "ChuYingBarrierLightWall"
	wall.add_to_group("chu_ying_light_walls")
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _light_wall_material()
	wall.mesh = quad
	wall.position = position
	wall.rotation.y = yaw
	add_child(wall)


func _light_wall_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
	float bottom_to_top = smoothstep(0.0, 0.92, UV.y);
	vec3 glow = vec3(0.56, 0.78, 1.0);
	ALBEDO = glow;
	EMISSION = glow * 1.8;
	ALPHA = bottom_to_top * 0.30;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func combat_snapshot() -> Dictionary:
	var ids: Array[int] = []
	for actor in trapped:
		if actor != null and is_instance_valid(actor):
			ids.append(actor.battle_id)
	ids.sort()
	var contained_positions: Dictionary = {}
	var contained_actor_ids: Array = last_contained_positions.keys()
	contained_actor_ids.sort()
	for actor_id_value in contained_actor_ids:
		var actor_id := int(actor_id_value)
		var position: Vector2 = last_contained_positions[actor_id]
		contained_positions[str(actor_id)] = [roundi(position.x * 10000.0), roundi(position.y * 10000.0)]
	return {
		"id": unit_id,
		"type": "chu_ying_barrier",
		"position": [roundi(global_position.x * 10000.0), roundi(global_position.y * 10000.0), roundi(global_position.z * 10000.0)],
		"half_extents": [roundi(half_extents.x * 10000.0), roundi(half_extents.y * 10000.0)],
		"remaining": roundi(remaining * 10000.0),
		"trapped": ids,
		"last_contained_positions": contained_positions,
	}


func authoritative_snapshot() -> Dictionary:
	var snapshot := combat_snapshot()
	snapshot["entity_id"] = entity_id
	snapshot["entity_kind"] = "chu_ying_barrier"
	snapshot["attack_id"] = unit_id
	snapshot["source_id"] = source.battle_id if source != null and is_instance_valid(source) else 0
	snapshot["ability_id"] = "ultimate"
	snapshot["vfx_id"] = "chu_ying_barrier"
	return snapshot


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.7
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
