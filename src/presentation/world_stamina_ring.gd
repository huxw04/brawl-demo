class_name WorldStaminaRing
extends Node3D

const SEGMENTS := 40

var actor: CombatActor
var background: MeshInstance3D
var fill: MeshInstance3D
var last_fill_steps := -1


func setup(p_actor: CombatActor) -> void:
	actor = p_actor
	top_level = true
	background = MeshInstance3D.new()
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.mesh = _arc_mesh(1.0, 0.105, 0.15, Color(0.025, 0.05, 0.07, 0.78), 0)
	add_child(background)
	fill = MeshInstance3D.new()
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A camera faces along its local -Z axis. Keep the fill slightly closer and
	# render it after the dark backing so transparent sorting cannot cover it.
	fill.position.z = -0.004
	add_child(fill)
	_update_fill(true)


func _process(_delta: float) -> void:
	if actor == null or not is_instance_valid(actor):
		visible = false
		return
	visible = actor.relation == CombatActor.Relation.SELF and not actor.is_defeated
	if not visible:
		return
	var camera := get_viewport().get_camera_3d()
	var screen_left := Vector3.LEFT
	if camera != null:
		screen_left = -camera.global_basis.x.normalized()
		global_basis = camera.global_basis.orthonormalized()
	global_position = actor.global_position + Vector3.UP * (actor.definition.body_height * 0.62) + screen_left * (actor.definition.body_radius + 0.28)
	_update_fill()


func _update_fill(force := false) -> void:
	if actor == null or fill == null:
		return
	var ratio := clampf(actor.stamina / maxf(actor.definition.max_stamina, 0.001), 0.0, 1.0)
	var steps := clampi(roundi(ratio * SEGMENTS), 0, SEGMENTS)
	if not force and steps == last_fill_steps:
		return
	last_fill_steps = steps
	fill.visible = steps > 0
	if steps > 0:
		fill.mesh = _arc_mesh(float(steps) / SEGMENTS, 0.112, 0.143, Color("84dcf2"), 1)


func _arc_mesh(ratio: float, inner_radius: float, outer_radius: float, color: Color, render_priority: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(1, ceili(SEGMENTS * clampf(ratio, 0.0, 1.0)))
	for index in range(count):
		var angle_a := -PI * 0.5 + TAU * ratio * float(index) / count
		var angle_b := -PI * 0.5 + TAU * ratio * float(index + 1) / count
		var inner_a := Vector3(cos(angle_a) * inner_radius, sin(angle_a) * inner_radius, 0.0)
		var outer_a := Vector3(cos(angle_a) * outer_radius, sin(angle_a) * outer_radius, 0.0)
		var inner_b := Vector3(cos(angle_b) * inner_radius, sin(angle_b) * inner_radius, 0.0)
		var outer_b := Vector3(cos(angle_b) * outer_radius, sin(angle_b) * outer_radius, 0.0)
		for vertex in [inner_a, outer_a, outer_b, inner_a, outer_b, inner_b]:
			surface.add_vertex(vertex)
	var mesh := surface.commit()
	mesh.surface_set_material(0, _material(color, render_priority))
	return mesh


func _material(color: Color, render_priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = render_priority
	return material
