class_name DelayedGroundAttack
extends Node3D

var source: CombatActor
var ability: AbilityDefinition
var attack_id := 0
var remaining := 0.0
var radius := 1.0
var cast_facing := Vector3.RIGHT
var indicator: Sprite3D
var glow_overlay: Sprite3D


func configure(p_source: CombatActor, p_ability: AbilityDefinition, p_attack_id: int, center: Vector3) -> void:
	source = p_source
	ability = p_ability
	attack_id = p_attack_id
	remaining = ability.delayed_delay
	radius = ability.delayed_radius
	cast_facing = p_source.facing.normalized() if p_source.facing.length_squared() > 0.001 else Vector3.RIGHT
	top_level = true
	global_position = Vector3(center.x, 0.065, center.z)
	add_to_group("transient_combat_vfx")
	_spawn_indicator()


func _physics_process(delta: float) -> void:
	remaining -= delta
	if indicator != null and remaining <= 0.22:
		var charge := clampf(1.0 - remaining / 0.22, 0.0, 1.0)
		indicator.modulate = Color.WHITE.lerp(Color(0.88, 0.96, 1.0, 1.0), charge)
		if glow_overlay != null and glow_overlay.material_override is ShaderMaterial:
			(glow_overlay.material_override as ShaderMaterial).set_shader_parameter("strength", charge)
	if remaining > 0.0:
		return
	_detonate()
	set_physics_process(false)
	queue_free()


func _spawn_indicator() -> void:
	var source_sword := source.visual_layer_sprites.get("shield_dog_sword") as Sprite3D
	if source_sword == null:
		return
	indicator = Sprite3D.new()
	indicator.name = "EmbeddedHeavySword"
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	indicator.texture = source_sword.texture
	indicator.pixel_size = source_sword.pixel_size
	indicator.offset = source_sword.offset
	indicator.flip_h = cast_facing.x < -0.05
	if indicator.flip_h:
		indicator.offset.x = -indicator.offset.x
	indicator.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	indicator.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	add_child(indicator)
	indicator.position = Vector3(0.0, 0.82 if not indicator.flip_h else 0.0, 0.0)
	var active_camera := get_viewport().get_camera_3d()
	var facing_sign := -1.0 if indicator.flip_h else 1.0
	var visual_scale := Vector3(2.35, 1.34, 1.0)
	if active_camera != null:
		indicator.global_basis = active_camera.global_basis.orthonormalized() * Basis(Vector3.BACK, facing_sign * -0.62) * Basis.from_scale(visual_scale)
	else:
		indicator.rotation.z = facing_sign * -0.62
		indicator.scale = visual_scale
	_spawn_glow_overlay(source_sword)


func _spawn_glow_overlay(source_sword: Sprite3D) -> void:
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
	var glow_material := ShaderMaterial.new()
	glow_material.shader = shader
	glow_material.set_shader_parameter("source_texture", source_sword.texture)
	glow_material.set_shader_parameter("strength", 0.0)
	glow_overlay.material_override = glow_material
	indicator.add_child(glow_overlay)


func _detonate() -> void:
	if not is_instance_valid(source):
		return
	if indicator != null:
		indicator.visible = false
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * ability.delayed_center_y)
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_targets: Dictionary = {}
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider = result.get("collider")
		if not collider is Area3D:
			continue
		var target = (collider as Area3D).get_meta("combat_actor", null)
		if not target is CombatActor or target == source or target.team == source.team:
			continue
		var target_id: int = target.get_instance_id()
		if hit_targets.has(target_id):
			continue
		hit_targets[target_id] = true
		var direction: Vector3 = target.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			direction = source.facing
		var hp_before: float = target.hp
		if target.receive_hit(source, ability, direction.normalized(), attack_id, ability.delayed_damage):
			source.on_ability_hit(ability, minf(hp_before, ability.delayed_damage))
	_spawn_shockwave()


func _spawn_shockwave() -> void:
	var wave := MeshInstance3D.new()
	wave.name = "DelayedGroundShockwave"
	wave.top_level = true
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(wave)
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
	tween.tween_property(wave, "scale", Vector3.ONE * radius * 1.18, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(wave, "transparency", 1.0, 0.28)
	tween.tween_callback(wave.queue_free)
	var flash := MeshInstance3D.new()
	flash.name = "DelayedSwordBurst"
	flash.top_level = true
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(flash)
	flash.global_position = global_position + Vector3.UP * 0.05
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.46
	disc.bottom_radius = radius * 0.46
	disc.height = 0.025
	disc.radial_segments = 48
	disc.material = _material(Color(1.0, 1.0, 1.0, 0.38))
	flash.mesh = disc
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "scale", Vector3(1.55, 0.25, 1.55), 0.16)
	flash_tween.parallel().tween_property(flash, "transparency", 1.0, 0.16)
	flash_tween.tween_callback(flash.queue_free)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material
