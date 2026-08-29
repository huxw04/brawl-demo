class_name MoveDestinationIndicator
extends Node3D

const MOVE_COLOR := Color(0.48, 0.92, 1.0, 0.68)
const INVALID_COLOR := Color(1.0, 0.38, 0.22, 0.82)

var actor: CombatActor
var marker: Node3D
var marker_parts: Array[GeometryInstance3D] = []
var marker_fading := false


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func show_destination(requested: Vector3, resolved: Vector3, reachable: bool) -> void:
	_spawn_click_ripple(requested, MOVE_COLOR if reachable else INVALID_COLOR)
	clear_destination()
	if not reachable:
		_spawn_invalid_cross(requested)
		return
	marker = Node3D.new()
	marker.name = "MoveDestination"
	marker.position = Vector3(resolved.x, 0.045, resolved.z)
	marker.scale = Vector3(0.62, 0.62, 0.62)
	add_child(marker)
	marker_parts.clear()
	marker_parts.append(_add_ring(marker, 0.19, 0.24, MOVE_COLOR))
	marker_parts.append(_add_disc(marker, 0.045, Color(MOVE_COLOR, 0.78)))
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var tick := _add_box(marker, direction * 0.31, Vector3(0.11, 0.018, 0.035), MOVE_COLOR)
		tick.rotation.y = atan2(direction.z, direction.x)
		marker_parts.append(tick)
	marker_fading = false
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(marker, "scale", Vector3.ONE, 0.14)


func clear_destination(animated := false) -> void:
	if marker == null or not is_instance_valid(marker):
		marker = null
		marker_parts.clear()
		marker_fading = false
		return
	if animated and not marker_fading:
		_fade_marker()
		return
	marker.queue_free()
	marker = null
	marker_parts.clear()
	marker_fading = false


func _process(_delta: float) -> void:
	if marker == null or not is_instance_valid(marker) or marker_fading or actor == null:
		return
	if actor.is_defeated:
		clear_destination(true)
		return
	var offset := actor.global_position - marker.global_position
	offset.y = 0.0
	if offset.length() <= 0.22:
		clear_destination(true)


func _fade_marker() -> void:
	marker_fading = true
	var fading_marker := marker
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fading_marker, "scale", Vector3(0.35, 0.35, 0.35), 0.16)
	for part in marker_parts:
		if is_instance_valid(part):
			tween.tween_property(part, "transparency", 1.0, 0.16)
	tween.chain().tween_callback(_finish_marker_fade.bind(fading_marker.get_instance_id()))


func _finish_marker_fade(fading_marker_id: int) -> void:
	var fading_marker := instance_from_id(fading_marker_id) as Node3D
	if is_instance_valid(fading_marker):
		fading_marker.queue_free()
	if marker != null and marker.get_instance_id() == fading_marker_id:
		marker = null
		marker_parts.clear()
		marker_fading = false


func _spawn_click_ripple(position: Vector3, color: Color) -> void:
	var ripple := _add_ring(self, 0.12, 0.17, color)
	ripple.position = Vector3(position.x, 0.05, position.z)
	ripple.scale = Vector3(0.7, 0.7, 0.7)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ripple, "scale", Vector3(1.65, 1.65, 1.65), 0.22)
	tween.tween_property(ripple, "transparency", 1.0, 0.22)
	tween.chain().tween_callback(ripple.queue_free)


func _spawn_invalid_cross(position: Vector3) -> void:
	var cross := Node3D.new()
	cross.position = Vector3(position.x, 0.055, position.z)
	add_child(cross)
	var first := _add_box(cross, Vector3.ZERO, Vector3(0.34, 0.02, 0.045), INVALID_COLOR)
	first.rotation.y = PI * 0.25
	var second := _add_box(cross, Vector3.ZERO, Vector3(0.34, 0.02, 0.045), INVALID_COLOR)
	second.rotation.y = -PI * 0.25
	var tween := create_tween().set_parallel(true)
	tween.tween_property(cross, "scale", Vector3(1.18, 1.18, 1.18), 0.28)
	tween.tween_property(first, "transparency", 1.0, 0.28)
	tween.tween_property(second, "transparency", 1.0, 0.28)
	tween.chain().tween_callback(cross.queue_free)


func _add_ring(parent: Node3D, inner_radius: float, outer_radius: float, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 32
	mesh.ring_segments = 6
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_disc(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.018
	mesh.radial_segments = 20
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 0.65
	return material
