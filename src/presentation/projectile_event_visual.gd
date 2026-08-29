class_name ProjectileEventVisual
extends Node3D

var entity_id := 0
var target: Node3D
var direction := Vector3.RIGHT
var event_source: Node
var source: Node3D
var vfx_id := ""
var body_visual: MeshInstance3D
var cable_visual: MeshInstance3D


func setup(p_entity_id: int, p_target: Node3D, initial_state: Dictionary, p_event_source: Node = null) -> void:
	entity_id = p_entity_id
	target = p_target
	event_source = p_event_source
	direction = _vector_from_packet(initial_state.get("direction", []), Vector3.RIGHT)
	vfx_id = str(initial_state.get("vfx_id", ""))
	var source_id := int(initial_state.get("source_id", 0))
	if event_source != null and event_source.has_method("entity"):
		source = event_source.call("entity", source_id) as Node3D
	name = "ProjectileEventVisual_%d" % entity_id
	add_to_group("authority_event_visuals")
	_build_projectile(initial_state)
	_sync_to_target()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_sync_to_target()
	if vfx_id == "bear_throw_knife" and body_visual != null:
		body_visual.rotation.z += delta * 21.0
	elif vfx_id == "bear_grapple":
		_update_grapple_cable()


func _sync_to_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position
	var live_direction = target.get("direction")
	if live_direction is Vector3 and (live_direction as Vector3).length_squared() > 0.001:
		direction = (live_direction as Vector3).normalized()
	rotation.y = atan2(-direction.x, -direction.z)


func _build_projectile(initial_state: Dictionary) -> void:
	match vfx_id:
		"sword_wave":
			_build_sword_wave()
		"bear_throw_knife":
			_build_throwing_knife()
		"chu_ying_homing_stone":
			_build_homing_stone(initial_state)
		"nailoong_fire_breath":
			_build_fireball(initial_state)
		"bear_grapple":
			_build_grapple()
		_:
			_build_generic(initial_state)


func _build_sword_wave() -> void:
	var pillar := MeshInstance3D.new()
	pillar.name = "SwordWavePillar"
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.16, 1.20, 0.12)
	pillar_mesh.material = _material(Color(0.94, 0.99, 1.0, 0.96), 3.2)
	pillar.mesh = pillar_mesh
	pillar.position.y = 0.08
	add_child(pillar)
	var glow := MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.25, 1.28, 0.20)
	glow_mesh.material = _material(Color(0.42, 0.82, 1.0, 0.24), 3.2)
	glow.mesh = glow_mesh
	pillar.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = Color("9feaff")
	light.light_energy = 2.2
	light.omni_range = 2.1
	light.shadow_enabled = false
	pillar.add_child(light)
	var trail := MeshInstance3D.new()
	trail.name = "SwordWaveTrail"
	trail.mesh = _exponential_trail_mesh()
	add_child(trail)


func _build_throwing_knife() -> void:
	body_visual = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.07, 0.035, 0.34)
	blade.material = _material(Color(0.82, 0.88, 0.86), 1.8)
	body_visual.mesh = blade
	add_child(body_visual)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.09, 0.055, 0.15)
	handle_mesh.material = _material(Color("26302b"), 1.8)
	handle.mesh = handle_mesh
	handle.position.z = 0.23
	body_visual.add_child(handle)


func _build_homing_stone(initial_state: Dictionary) -> void:
	body_visual = MeshInstance3D.new()
	var stone := CylinderMesh.new()
	var radius := _radius(initial_state, 0.12)
	stone.top_radius = radius
	stone.bottom_radius = radius
	stone.height = 0.048
	stone.radial_segments = 28
	stone.material = _material(Color("f0f2f5") if int(initial_state.get("attack_id", 0)) % 2 == 0 else Color("181b21"), 1.8)
	body_visual.mesh = stone
	body_visual.rotation.x = PI * 0.5
	add_child(body_visual)


func _build_fireball(initial_state: Dictionary) -> void:
	body_visual = MeshInstance3D.new()
	var radius := _radius(initial_state, 0.14)
	var flame := SphereMesh.new()
	flame.radius = radius
	flame.height = radius * 2.0
	flame.material = _material(Color(1.0, 0.28, 0.025, 0.94), 1.8)
	body_visual.mesh = flame
	body_visual.scale = Vector3(1.45, 0.88, 1.0)
	add_child(body_visual)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = radius * 0.55
	core_mesh.height = radius * 1.10
	core_mesh.material = _material(Color(1.0, 0.88, 0.22, 0.98), 1.8)
	core.mesh = core_mesh
	body_visual.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color("ff7a26")
	light.light_energy = 1.7
	light.omni_range = 1.15
	light.shadow_enabled = false
	body_visual.add_child(light)


func _build_grapple() -> void:
	body_visual = MeshInstance3D.new()
	var hook := SphereMesh.new()
	hook.radius = 0.12
	hook.height = 0.24
	hook.material = _material(Color("9caaa2"), 1.8)
	body_visual.mesh = hook
	add_child(body_visual)
	for side in [-1.0, 1.0]:
		var prong := MeshInstance3D.new()
		var prong_mesh := BoxMesh.new()
		prong_mesh.size = Vector3(0.045, 0.045, 0.22)
		prong_mesh.material = _material(Color("c8d2cc"), 1.8)
		prong.mesh = prong_mesh
		prong.position = Vector3(side * 0.09, 0.0, -0.13)
		prong.rotation.y = side * 0.46
		body_visual.add_child(prong)
	cable_visual = MeshInstance3D.new()
	cable_visual.top_level = true
	cable_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cable := CylinderMesh.new()
	cable.top_radius = 0.018
	cable.bottom_radius = 0.018
	cable.height = 1.0
	cable.radial_segments = 8
	cable.material = _material(Color(0.52, 0.60, 0.56, 0.92), 1.8)
	cable_visual.mesh = cable
	add_child(cable_visual)
	_update_grapple_cable()


func _build_generic(initial_state: Dictionary) -> void:
	body_visual = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var radius := _radius(initial_state, 0.18)
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.material = _material(_color(initial_state, Color.WHITE), 1.8)
	body_visual.mesh = sphere
	add_child(body_visual)


func _update_grapple_cable() -> void:
	if cable_visual == null or source == null or not is_instance_valid(source):
		if cable_visual != null:
			cable_visual.visible = false
		return
	var source_facing = source.get("facing")
	var facing := source_facing as Vector3 if source_facing is Vector3 else Vector3.RIGHT
	var start := source.global_position + Vector3.UP * 1.02 + facing * 0.30
	var finish := global_position
	var cable_delta := finish - start
	var length := cable_delta.length()
	if length <= 0.001:
		cable_visual.visible = false
		return
	cable_visual.visible = true
	var up := cable_delta / length
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() <= 0.001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(up).normalized()
	cable_visual.global_transform = Transform3D(Basis(right, up, forward), (start + finish) * 0.5)
	cable_visual.scale = Vector3(1.0, length, 1.0)


func _radius(initial_state: Dictionary, fallback: float) -> float:
	var value := float(initial_state.get("radius", fallback))
	return value / 10000.0 if value > 100.0 else value


func _color(initial_state: Dictionary, fallback: Color) -> Color:
	var packet = initial_state.get("color", [])
	if packet is Array and (packet as Array).size() >= 4:
		var divisor := 10000.0 if float(packet[0]) > 1.0 or float(packet[1]) > 1.0 or float(packet[2]) > 1.0 or float(packet[3]) > 1.0 else 1.0
		return Color(float(packet[0]) / divisor, float(packet[1]) / divisor, float(packet[2]) / divisor, float(packet[3]) / divisor)
	return fallback


func _exponential_trail_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 14
	var trail_length := 2.25
	var half_width := 0.08
	var bottom := -0.52
	for index in range(segments):
		var distance_0 := trail_length * float(index) / segments
		var distance_1 := trail_length * float(index + 1) / segments
		var height_0 := 1.20 * exp(-1.75 * distance_0)
		var height_1 := 1.20 * exp(-1.75 * distance_1)
		var alpha_0 := 0.58 * exp(-1.35 * distance_0)
		var alpha_1 := 0.58 * exp(-1.35 * distance_1)
		var bottom_0_left := Vector3(-half_width, bottom, distance_0)
		var bottom_0_right := Vector3(half_width, bottom, distance_0)
		var top_0_left := Vector3(-half_width, bottom + height_0, distance_0)
		var top_0_right := Vector3(half_width, bottom + height_0, distance_0)
		var bottom_1_left := Vector3(-half_width, bottom, distance_1)
		var bottom_1_right := Vector3(half_width, bottom, distance_1)
		var top_1_left := Vector3(-half_width, bottom + height_1, distance_1)
		var top_1_right := Vector3(half_width, bottom + height_1, distance_1)
		var vertices := [
			top_0_left, top_0_right, top_1_right, top_0_left, top_1_right, top_1_left,
			bottom_0_left, top_0_left, top_1_left, bottom_0_left, top_1_left, bottom_1_left,
			top_0_right, bottom_0_right, bottom_1_right, top_0_right, bottom_1_right, top_1_right,
		]
		var alphas := [
			alpha_0, alpha_0, alpha_1, alpha_0, alpha_1, alpha_1,
			alpha_0, alpha_0, alpha_1, alpha_0, alpha_1, alpha_1,
			alpha_0, alpha_0, alpha_1, alpha_0, alpha_1, alpha_1,
		]
		for vertex_index in range(vertices.size()):
			surface.set_color(Color(0.62, 0.91, 1.0, alphas[vertex_index]))
			surface.add_vertex(vertices[vertex_index])
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


func _material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _vector_from_packet(packet: Variant, fallback: Vector3) -> Vector3:
	if packet is Array and (packet as Array).size() >= 3:
		return Vector3(float(packet[0]), float(packet[1]), float(packet[2])).normalized()
	return fallback
