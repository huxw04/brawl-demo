class_name WorldEntityEventVisual
extends Node3D

var entity_id := 0
var entity_kind := ""
var target: Node3D
var source: CombatActor
var indicator: Sprite3D
var glow_overlay: Sprite3D
var stone_visual: MeshInstance3D
var radius := 1.0


func setup(p_entity_id: int, p_entity_kind: String, p_target: Node3D, initial_state: Dictionary, event_source: Node) -> void:
	entity_id = p_entity_id
	entity_kind = p_entity_kind
	target = p_target
	name = "WorldEntityEventVisual_%d" % entity_id
	add_to_group("authority_event_visuals")
	if event_source != null and event_source.has_method("entity"):
		source = event_source.call("entity", int(initial_state.get("source_id", 0))) as CombatActor
	radius = float(initial_state.get("radius", 1.0))
	match entity_kind:
		"delayed_attack":
			_build_delayed_sword(initial_state)
		"chu_ying_stone":
			_build_stone(initial_state)
		"chu_ying_barrier":
			_build_barrier(initial_state)
	_sync_position()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_sync_position()
	if entity_kind == "delayed_attack":
		var live_remaining := float(target.get("remaining"))
		if indicator != null and live_remaining <= 0.22:
			var charge := clampf(1.0 - live_remaining / 0.22, 0.0, 1.0)
			indicator.modulate = Color.WHITE.lerp(Color(0.88, 0.96, 1.0, 1.0), charge)
			if glow_overlay != null and glow_overlay.material_override is ShaderMaterial:
				(glow_overlay.material_override as ShaderMaterial).set_shader_parameter("strength", charge)
	elif entity_kind == "chu_ying_stone" and stone_visual != null:
		if bool(target.get("flying")):
			stone_visual.rotation.y += delta * 18.0
			stone_visual.rotation.z += delta * 13.0
		elif float(target.get("fall_remaining")) > 0.0:
			stone_visual.rotation.y += delta * 9.0


func finish(reason: String) -> void:
	if entity_kind == "delayed_attack" and reason == "detonated":
		_spawn_delayed_shockwave()


func _sync_position() -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position


func _build_delayed_sword(initial_state: Dictionary) -> void:
	radius = float(initial_state.get("radius", 1.0))
	var direction := _vector3(initial_state.get("direction", []), Vector3.RIGHT)
	var source_sword := source.visual_layer_sprites.get("shield_dog_sword") as Sprite3D if source != null else null
	if source_sword == null:
		return
	indicator = Sprite3D.new()
	indicator.name = "EmbeddedHeavySword"
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	indicator.texture = source_sword.texture
	indicator.pixel_size = source_sword.pixel_size
	indicator.offset = source_sword.offset
	indicator.flip_h = direction.x < -0.05
	if indicator.flip_h:
		indicator.offset.x = -indicator.offset.x
	indicator.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	indicator.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	add_child(indicator)
	indicator.position = Vector3(0.0, 0.82 if not indicator.flip_h else 0.0, 0.0)
	var camera := get_viewport().get_camera_3d()
	var facing_sign := -1.0 if indicator.flip_h else 1.0
	var visual_scale := Vector3(2.35, 1.34, 1.0)
	if camera != null:
		indicator.global_basis = camera.global_basis.orthonormalized() * Basis(Vector3.BACK, facing_sign * -0.62) * Basis.from_scale(visual_scale)
	else:
		indicator.rotation.z = facing_sign * -0.62
		indicator.scale = visual_scale
	_build_delayed_glow(source_sword)


func _build_delayed_glow(source_sword: Sprite3D) -> void:
	glow_overlay = Sprite3D.new()
	glow_overlay.name = "EmbeddedHeavySwordGlow"
	glow_overlay.texture = source_sword.texture
	glow_overlay.pixel_size = source_sword.pixel_size
	glow_overlay.offset = indicator.offset
	glow_overlay.flip_h = indicator.flip_h
	glow_overlay.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	glow_overlay.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	glow_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_overlay.position.z = 0.01
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform float strength = 0.0;
void fragment() {
	vec4 c = texture(source_texture, UV);
	ALBEDO = vec3(0.82, 0.94, 1.0);
	EMISSION = vec3(1.2, 1.65, 2.2) * strength * 2.4;
	ALPHA = c.a * strength * 0.88;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("source_texture", source_sword.texture)
	material.set_shader_parameter("strength", 0.0)
	glow_overlay.material_override = material
	indicator.add_child(glow_overlay)


func _build_stone(initial_state: Dictionary) -> void:
	stone_visual = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.14
	mesh.bottom_radius = 0.14
	mesh.height = 0.055
	mesh.radial_segments = 32
	mesh.material = _material(Color("15181d") if int(initial_state.get("attack_id", 0)) % 2 == 0 else Color("f2f3ef"))
	stone_visual.mesh = mesh
	stone_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(stone_visual)


func _build_barrier(initial_state: Dictionary) -> void:
	var half := _vector2(initial_state.get("half_extents", []), Vector2(0.5, 0.5))
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(half.x * 2.0, 0.025, half.y * 2.0)
	floor_mesh.material = _material(Color(0.45, 0.66, 0.92, 0.10))
	floor.mesh = floor_mesh
	add_child(floor)
	_add_edge(Vector3(0.0, 0.05, -half.y), Vector3(half.x * 2.0, 0.08, 0.06))
	_add_edge(Vector3(0.0, 0.05, half.y), Vector3(half.x * 2.0, 0.08, 0.06))
	_add_edge(Vector3(-half.x, 0.05, 0.0), Vector3(0.06, 0.08, half.y * 2.0))
	_add_edge(Vector3(half.x, 0.05, 0.0), Vector3(0.06, 0.08, half.y * 2.0))
	var wall_height := maxf(0.65, maxf(half.x * 2.0, half.y * 2.0) * 0.55)
	_add_light_wall(Vector3(0.0, wall_height * 0.5, -half.y), Vector2(half.x * 2.0, wall_height), 0.0)
	_add_light_wall(Vector3(0.0, wall_height * 0.5, half.y), Vector2(half.x * 2.0, wall_height), 0.0)
	_add_light_wall(Vector3(-half.x, wall_height * 0.5, 0.0), Vector2(half.y * 2.0, wall_height), PI * 0.5)
	_add_light_wall(Vector3(half.x, wall_height * 0.5, 0.0), Vector2(half.y * 2.0, wall_height), PI * 0.5)


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


func _spawn_delayed_shockwave() -> void:
	var world := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	var wave := MeshInstance3D.new()
	wave.name = "DelayedGroundShockwave"
	wave.top_level = true
	world.add_child(wave)
	wave.global_position = global_position + Vector3.UP * 0.025
	var ring := TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 10
	ring.material = _material(Color(0.93, 0.97, 1.0, 0.56))
	wave.mesh = ring
	wave.scale = Vector3.ONE * radius * 0.20
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3.ONE * radius * 1.18, 0.28)
	tween.parallel().tween_property(wave, "transparency", 1.0, 0.28)
	tween.tween_callback(wave.queue_free)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.7
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


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


func _vector3(packet: Variant, fallback: Vector3) -> Vector3:
	if packet is Array and (packet as Array).size() >= 3:
		return Vector3(float(packet[0]), float(packet[1]), float(packet[2])).normalized()
	return fallback


func _vector2(packet: Variant, fallback: Vector2) -> Vector2:
	if packet is Array and (packet as Array).size() >= 2:
		var result := Vector2(float(packet[0]), float(packet[1]))
		return result / 10000.0 if result.x > 100.0 or result.y > 100.0 else result
	return fallback
