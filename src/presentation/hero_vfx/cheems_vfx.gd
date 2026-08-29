class_name CheemsVfx
extends Node

## Pure presentation for Cheems. Energy, hit pulses, second-stage validation
## and damage remain in the authoritative combat layer.

const MAGIC_CIRCLE = preload("res://assets/heroes/cheems/vfx/cheems_magic_circle_v1.png")

var actor: CombatActor
var active_magic_circle: Node3D
var magic_circle_lifetime_tween: Tween
var visual_offset := Vector3.ZERO
var visual_from := Vector3.ZERO
var visual_to := Vector3.ZERO
var visual_segment_remaining := 0.0
var visual_segment_duration := 0.0
var multi_slash_ability: AbilityDefinition
var multi_slash_remaining := 0.0
var multi_slash_emit_remaining := 0.0
var multi_slash_seen_active := false


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func reset() -> void:
	dismiss_magic_circle(0.0)
	visual_offset = Vector3.ZERO
	visual_from = Vector3.ZERO
	visual_to = Vector3.ZERO
	visual_segment_remaining = 0.0
	visual_segment_duration = 0.0
	multi_slash_ability = null
	multi_slash_remaining = 0.0
	multi_slash_emit_remaining = 0.0
	multi_slash_seen_active = false


func start_horizontal_slashes(ability: AbilityDefinition, duration: float) -> void:
	multi_slash_ability = ability
	multi_slash_remaining = maxf(duration, 0.0)
	multi_slash_emit_remaining = 0.0
	multi_slash_seen_active = false


func update_continuous_visuals(delta: float) -> void:
	if multi_slash_ability == null or multi_slash_remaining <= 0.0:
		return
	var active := actor.current_ability != null and actor.current_ability.vfx_id == "multi_slash" and actor.ability_phase == "active"
	if active:
		multi_slash_seen_active = true
	elif multi_slash_seen_active:
		multi_slash_remaining = 0.0
		multi_slash_ability = null
		return
	multi_slash_remaining = maxf(0.0, multi_slash_remaining - delta)
	multi_slash_emit_remaining -= delta
	while multi_slash_emit_remaining <= 0.0 and multi_slash_remaining > 0.0:
		spawn_horizontal_slash(multi_slash_ability)
		multi_slash_emit_remaining += 0.09
	if multi_slash_remaining <= 0.0:
		multi_slash_ability = null


func spawn_magic_circle(ability: AbilityDefinition, duration: float) -> void:
	if is_instance_valid(active_magic_circle):
		active_magic_circle.queue_free()
	var anchor := Node3D.new()
	anchor.name = "DimensionalMagicCircle"
	anchor.top_level = true
	_world_parent().add_child(anchor)
	active_magic_circle = anchor
	anchor.global_position = Vector3(actor.global_position.x, 0.032, actor.global_position.z)
	var mirror := MeshInstance3D.new()
	mirror.name = "Mirror"
	var mirror_mesh := CylinderMesh.new()
	mirror_mesh.top_radius = ability.hitbox_radius * 1.02
	mirror_mesh.bottom_radius = ability.hitbox_radius * 1.02
	mirror_mesh.height = 0.018
	mirror_mesh.radial_segments = 64
	var mirror_material := _base_material(Color(0.025, 0.055, 0.10, 0.075))
	mirror_material.metallic = 0.92
	mirror_material.roughness = 0.12
	mirror_mesh.material = mirror_material
	mirror.mesh = mirror_mesh
	anchor.add_child(mirror)
	var circle := MeshInstance3D.new()
	circle.name = "Circle"
	var quad := QuadMesh.new()
	quad.size = Vector2(ability.hitbox_radius * 2.08, ability.hitbox_radius * 2.08)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D circle_texture : source_color, filter_linear_mipmap;
uniform float opacity = 0.70;
void fragment() {
	vec4 c = texture(circle_texture, UV);
	float lightness = max(c.r, max(c.g, c.b));
	ALBEDO = c.rgb;
	EMISSION = c.rgb * 2.8;
	ALPHA = smoothstep(0.035, 0.22, lightness) * opacity;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("circle_texture", MAGIC_CIRCLE)
	quad.material = material
	circle.mesh = quad
	circle.rotation.x = -PI * 0.5
	circle.position.y = 0.012
	circle.scale = Vector3.ONE
	anchor.add_child(circle)
	var spin := circle.create_tween()
	spin.tween_property(circle, "rotation:z", TAU * 0.16, duration)
	magic_circle_lifetime_tween = anchor.create_tween()
	magic_circle_lifetime_tween.tween_interval(maxf(0.0, duration - 0.20))
	magic_circle_lifetime_tween.tween_property(circle, "transparency", 1.0, 0.20)
	magic_circle_lifetime_tween.parallel().tween_property(mirror, "transparency", 1.0, 0.20)
	magic_circle_lifetime_tween.tween_callback(anchor.queue_free)


func dismiss_magic_circle(duration: float) -> void:
	if not is_instance_valid(active_magic_circle):
		active_magic_circle = null
		return
	if magic_circle_lifetime_tween != null and magic_circle_lifetime_tween.is_valid():
		magic_circle_lifetime_tween.kill()
	var anchor := active_magic_circle
	active_magic_circle = null
	if duration <= 0.0:
		anchor.queue_free()
		return
	var circle := anchor.get_node_or_null("Circle") as MeshInstance3D
	var mirror := anchor.get_node_or_null("Mirror") as MeshInstance3D
	var tween := anchor.create_tween()
	if circle != null:
		tween.tween_property(circle, "transparency", 1.0, duration)
	if mirror != null:
		tween.parallel().tween_property(mirror, "transparency", 1.0, duration)
	tween.tween_callback(anchor.queue_free)


func spawn_horizontal_slash(ability: AbilityDefinition) -> void:
	if ability.vfx_id != "multi_slash":
		return
	var slash := MeshInstance3D.new()
	slash.name = "MultiSlashVisual"
	slash.add_to_group("transient_combat_vfx")
	slash.top_level = true
	_world_parent().add_child(slash)
	var side := Vector3(-actor.facing.z, 0.0, actor.facing.x)
	var random_height := actor.visual_rng.randf_range(0.34, 1.16)
	var lateral_offset := actor.visual_rng.randf_range(-0.20, 0.20)
	var start := actor.global_position + actor.facing * 0.52 + side * lateral_offset + Vector3.UP * random_height
	slash.global_position = start
	slash.rotation.y = atan2(-actor.facing.x, -actor.facing.z)
	slash.rotate_object_local(Vector3.FORWARD, deg_to_rad(actor.visual_rng.randf_range(-22.0, 22.0)))
	slash.mesh = _horizontal_crescent_mesh(Color(0.88, 0.96, 1.0, 0.50))
	var visual_scale := actor.visual_rng.randf_range(0.78, 1.08)
	slash.scale = Vector3(0.24, 0.24, 0.24) * visual_scale
	var destination := start + actor.facing * actor.visual_rng.randf_range(1.55, 2.15)
	var move_tween := slash.create_tween()
	move_tween.tween_property(slash, "global_position", destination, 0.28)
	move_tween.parallel().tween_property(slash, "scale", Vector3.ONE * visual_scale, 0.28)
	var fade_tween := slash.create_tween()
	fade_tween.tween_interval(0.12)
	fade_tween.tween_property(slash, "transparency", 1.0, 0.16)
	fade_tween.tween_callback(slash.queue_free)
	_spawn_katana_afterimage()


func spawn_dimensional_cut(ability: AbilityDefinition, pulse_index: int) -> void:
	if pulse_index == 1:
		var line_count := 22
		for line_index in range(line_count):
			_spawn_dimensional_line(ability, line_index, line_count)
	var ghost_angle := actor.visual_rng.randf_range(0.0, TAU)
	var ghost_offset := Vector3(cos(ghost_angle), 0.0, sin(ghost_angle)) * actor.visual_rng.randf_range(0.85, 1.55)
	_spawn_afterimage(ghost_offset)
	if pulse_index >= ability.max_hits_per_target:
		_spawn_shatter(ability.hitbox_radius)


func update_dimensional_motion(delta: float, radius: float) -> void:
	if visual_segment_remaining <= 0.0:
		visual_from = visual_offset
		var angle := actor.visual_rng.randf_range(0.0, TAU)
		var distance := radius * 0.82 * pow(actor.visual_rng.randf(), 0.34)
		visual_to = Vector3(cos(angle), 0.0, sin(angle)) * distance
		visual_segment_duration = actor.visual_rng.randf_range(0.075, 0.14)
		visual_segment_remaining = visual_segment_duration
	visual_segment_remaining = maxf(0.0, visual_segment_remaining - delta)
	var progress := 1.0 - visual_segment_remaining / maxf(visual_segment_duration, 0.001)
	visual_offset = visual_from.lerp(visual_to, progress)


func relax_dimensional_motion(delta: float) -> void:
	visual_offset = visual_offset.move_toward(Vector3.ZERO, delta * 8.0)
	visual_segment_remaining = 0.0


func _spawn_katana_afterimage() -> void:
	var source_layer := actor.visual_layer_sprites.get("katana_action") as Sprite3D
	if source_layer == null:
		return
	var ghost := Sprite3D.new()
	ghost.add_to_group("transient_combat_vfx")
	ghost.top_level = true
	ghost.texture = source_layer.texture
	ghost.pixel_size = source_layer.pixel_size
	ghost.offset = source_layer.offset
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.flip_h = source_layer.flip_h
	ghost.modulate = Color(0.86, 0.94, 1.0, 0.42)
	_world_parent().add_child(ghost)
	ghost.global_position = source_layer.global_position
	_set_camera_facing_angle(ghost, float(source_layer.get_meta("visual_angle", 0.0)))
	ghost.scale = source_layer.scale
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.16)
	tween.tween_callback(ghost.queue_free)


func _spawn_dimensional_line(ability: AbilityDefinition, line_index: int, line_count: int) -> void:
	var line := MeshInstance3D.new()
	line.name = "DimensionalCutLine"
	line.add_to_group("transient_combat_vfx")
	line.add_to_group("dimensional_cut_lines")
	line.top_level = true
	_world_parent().add_child(line)
	const GOLDEN_ANGLE := 2.39996323
	var radial_rank := (line_index * 7) % maxi(line_count, 1)
	var radial_sample := (float(radial_rank) + actor.visual_rng.randf_range(0.18, 0.82)) / maxf(float(line_count), 1.0)
	var radial_angle := fposmod(float(line_index) * GOLDEN_ANGLE + actor.visual_rng.randf_range(-0.18, 0.18), TAU)
	var radial_distance := ability.hitbox_radius * 0.82 * pow(radial_sample, 0.36)
	var center_offset := Vector3(cos(radial_angle), 0.0, sin(radial_angle)) * radial_distance
	line.global_position = actor.global_position + center_offset + Vector3.UP * actor.visual_rng.randf_range(0.30, 1.42)
	var yaw := actor.visual_rng.randf_range(0.0, TAU)
	var elevation := actor.visual_rng.randf_range(-0.42, 0.42)
	var line_direction := Vector3(cos(yaw) * cos(elevation), sin(elevation), sin(yaw) * cos(elevation)).normalized()
	line.quaternion = Quaternion(Vector3.UP, line_direction)
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = actor.visual_rng.randf_range(0.012, 0.024)
	line_mesh.bottom_radius = line_mesh.top_radius
	line_mesh.height = ability.hitbox_radius * actor.visual_rng.randf_range(1.45, 2.15)
	line_mesh.radial_segments = 8
	line_mesh.rings = 1
	line_mesh.material = _vfx_material(Color(0.90, 0.97, 1.0, actor.visual_rng.randf_range(0.72, 0.96)))
	line.mesh = line_mesh
	line.scale = Vector3(1.0, 0.012, 1.0)
	var distribution := float(line_index) / maxf(float(line_count - 1), 1.0)
	var appear_delay := pow(distribution, 2.0) * 1.42
	var grow_duration := 0.08
	var hold_duration := maxf(0.0, 1.5 - appear_delay - grow_duration)
	var line_tween := line.create_tween()
	line_tween.tween_interval(appear_delay)
	line_tween.tween_property(line, "scale:y", 1.0, grow_duration)
	line_tween.tween_interval(hold_duration)
	line_tween.tween_property(line, "scale", Vector3(0.06, 1.04, 0.06), 0.5)
	line_tween.parallel().tween_property(line, "transparency", 1.0, 0.5)
	line_tween.tween_callback(line.queue_free)


func _spawn_afterimage(offset: Vector3) -> void:
	var ghost := Sprite3D.new()
	ghost.add_to_group("transient_combat_vfx")
	ghost.top_level = true
	ghost.texture = actor.definition.sprite_texture
	ghost.pixel_size = actor.definition.sprite_pixel_size
	ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.modulate = Color(0.72, 0.84, 1.0, 0.45)
	_world_parent().add_child(ghost)
	ghost.global_position = actor.global_position + offset + Vector3.UP * actor.definition.sprite_y
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.48)
	tween.tween_callback(ghost.queue_free)


func _spawn_shatter(radius: float) -> void:
	for index in range(10):
		var angle := TAU * float(index) / 10.0
		var shard := MeshInstance3D.new()
		shard.add_to_group("transient_combat_vfx")
		shard.top_level = true
		_world_parent().add_child(shard)
		shard.global_position = actor.global_position + Vector3.UP * 0.12
		shard.rotation.y = -angle
		var shard_mesh := BoxMesh.new()
		shard_mesh.size = Vector3(0.34 + 0.05 * float(index % 3), 0.035, 0.08)
		shard_mesh.material = _vfx_material(Color(0.78, 0.86, 1.0, 0.78))
		shard.mesh = shard_mesh
		var destination := shard.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.72
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", destination, 0.24)
		tween.parallel().tween_property(shard, "transparency", 1.0, 0.3)
		tween.tween_callback(shard.queue_free)


func _horizontal_crescent_mesh(color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 22
	for index in range(segments):
		var a0 := deg_to_rad(-72.0 + 144.0 * float(index) / segments)
		var a1 := deg_to_rad(-72.0 + 144.0 * float(index + 1) / segments)
		var inner0 := Vector3(sin(a0) * 0.90, 0.0, -cos(a0) * 0.42)
		var outer0 := Vector3(sin(a0), 0.0, -cos(a0) * 0.54)
		var inner1 := Vector3(sin(a1) * 0.90, 0.0, -cos(a1) * 0.42)
		var outer1 := Vector3(sin(a1), 0.0, -cos(a1) * 0.54)
		for vertex in [inner0, outer0, outer1, inner0, outer1, inner1]:
			surface.add_vertex(vertex)
	var mesh := surface.commit()
	mesh.surface_set_material(0, _vfx_material(color))
	return mesh


func _set_camera_facing_angle(layer_sprite: Sprite3D, angle: float) -> void:
	layer_sprite.set_meta("visual_angle", angle)
	var active_camera := actor.get_viewport().get_camera_3d()
	if active_camera == null:
		layer_sprite.rotation.z = angle
		return
	var visual_scale := layer_sprite.scale
	layer_sprite.global_basis = active_camera.global_basis.orthonormalized() * Basis(Vector3.BACK, angle) * Basis.from_scale(visual_scale)


func _world_parent() -> Node:
	return actor.get_parent()


func _base_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material


func _vfx_material(color: Color) -> StandardMaterial3D:
	var material := _base_material(color)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
