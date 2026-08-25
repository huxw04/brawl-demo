class_name ChuYingBarrier
extends Node3D

var source: CombatActor
var unit_id := 0
var radius := 1.0
var remaining := 15.0
var trapped: Array[CombatActor] = []


func configure(p_source: CombatActor, center: Vector3, p_radius: float, p_unit_id: int) -> void:
	source = p_source
	unit_id = p_unit_id
	radius = maxf(p_radius, 0.12)
	global_position = Vector3(center.x, 0.06, center.z)
	add_to_group("deterministic_combat_units")
	add_to_group("transient_combat_vfx")
	for value in get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var actor := value as CombatActor
			var offset := actor.global_position - global_position
			offset.y = 0.0
			if actor != source and actor.team != source.team and not actor.is_defeated and offset.length() <= radius:
				trapped.append(actor)
	_create_visual()


func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	for actor in trapped:
		if actor == null or not is_instance_valid(actor) or actor.is_defeated:
			continue
		var offset := actor.global_position - global_position
		offset.y = 0.0
		var allowed := maxf(0.05, radius - actor.definition.body_radius * 0.55)
		if offset.length() > allowed:
			var clamped := offset.normalized() * allowed
			actor.global_position.x = global_position.x + clamped.x
			actor.global_position.z = global_position.z + clamped.z


func _create_visual() -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(0.04, radius - 0.08)
	ring_mesh.outer_radius = radius
	ring_mesh.rings = 64
	ring_mesh.ring_segments = 8
	ring_mesh.material = _material(Color(0.76, 0.88, 1.0, 0.86))
	ring.mesh = ring_mesh
	add_child(ring)
	var wall := MeshInstance3D.new()
	var wall_mesh := CylinderMesh.new()
	wall_mesh.top_radius = radius
	wall_mesh.bottom_radius = radius
	wall_mesh.height = 0.72
	wall_mesh.radial_segments = 64
	wall_mesh.material = _material(Color(0.45, 0.66, 0.92, 0.10))
	wall.mesh = wall_mesh
	wall.position.y = 0.36
	add_child(wall)


func combat_snapshot() -> Dictionary:
	var ids: Array[int] = []
	for actor in trapped:
		if actor != null and is_instance_valid(actor):
			ids.append(actor.battle_id)
	ids.sort()
	return {
		"id": unit_id,
		"type": "chu_ying_barrier",
		"position": [roundi(global_position.x * 10000.0), roundi(global_position.y * 10000.0), roundi(global_position.z * 10000.0)],
		"radius": roundi(radius * 10000.0),
		"remaining": roundi(remaining * 10000.0),
		"trapped": ids,
	}


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
