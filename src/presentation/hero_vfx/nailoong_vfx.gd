class_name NailoongVfx
extends Node

## Pure presentation for Nailoong. Combat timing and damage stay in CombatActor;
## this component only creates transient meshes and tweens.

var actor: CombatActor
var roll_dust_remaining := 0.0


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func update_continuous_visuals(delta: float) -> void:
	var rolling := actor.current_ability != null and actor.current_ability.vfx_id == "nailoong_roll" and actor.ability_phase == "active"
	if not rolling:
		roll_dust_remaining = 0.0
		return
	roll_dust_remaining -= delta
	while roll_dust_remaining <= 0.0:
		spawn_roll_dust()
		roll_dust_remaining += 0.08


func spawn_tail_sweep(radius: float) -> void:
	var ring := _spawn_ring(Vector3(actor.global_position.x, 0.065, actor.global_position.z), radius * 0.80, radius, Color(0.96, 0.99, 1.0, 0.52))
	ring.name = "NailoongBasicShockwave"
	ring.scale = Vector3.ONE * 0.18
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.10, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.26)
	tween.tween_callback(ring.queue_free)


func spawn_roll_dust() -> void:
	var dust := MeshInstance3D.new()
	dust.name = "NailoongRollDust"
	dust.top_level = true
	dust.add_to_group("transient_combat_vfx")
	_world_parent().add_child(dust)
	dust.global_position = Vector3(actor.global_position.x, 0.13, actor.global_position.z) - actor.nailoong_roll_direction * 0.32
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.20
	mesh.material = _vfx_material(Color(1.0, 0.86, 0.45, 0.42))
	dust.mesh = mesh
	dust.scale = Vector3(1.4, 0.42, 0.85)
	var tween := dust.create_tween()
	tween.tween_property(dust, "scale", Vector3(2.1, 0.15, 1.35), 0.20)
	tween.parallel().tween_property(dust, "transparency", 1.0, 0.20)
	tween.tween_callback(dust.queue_free)


func spawn_bounce_flash(position: Vector3) -> void:
	var flash := _spawn_ring(position + Vector3.UP * 0.55, 0.12, 0.22, Color(1.0, 0.93, 0.45, 0.86))
	flash.rotation.x = PI * 0.5
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.8, 0.14)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.14)
	tween.tween_callback(flash.queue_free)


func spawn_fire_muzzle() -> void:
	var ring := _spawn_ring(actor.global_position + actor.facing * 0.52 + Vector3.UP * 0.78, 0.08, 0.16, Color(1.0, 0.34, 0.06, 0.86))
	ring.name = "NailoongFireMuzzle"
	ring.rotation.x = PI * 0.5
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.0, 0.16)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.18)
	tween.tween_callback(ring.queue_free)


func spawn_takeoff_ring() -> void:
	spawn_takeoff_ring_at(actor.global_position)


func spawn_takeoff_ring_at(position: Vector3) -> void:
	var ring := _spawn_ring(Vector3(position.x, 0.05, position.z), 0.24, 0.42, Color(1.0, 0.88, 0.30, 0.62))
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.9, 0.24)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.24)
	tween.tween_callback(ring.queue_free)


func spawn_landing_wave(radius: float) -> void:
	spawn_landing_wave_at(actor.global_position, radius)


func spawn_landing_wave_at(position: Vector3, radius: float) -> void:
	var ring := _spawn_ring(Vector3(position.x, 0.06, position.z), radius * 0.78, radius, Color(0.96, 0.99, 1.0, 0.56))
	ring.name = "NailoongLandingShockwave"
	ring.scale = Vector3(0.18, 0.18, 0.18)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.18, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.32)
	tween.tween_callback(ring.queue_free)


func spawn_laugh_wave() -> void:
	for index in range(3):
		var ring := _spawn_ring(actor.global_position + Vector3.UP * (0.72 + index * 0.18), 0.18, 0.28, Color(0.70, 1.0, 0.40, 0.58 - index * 0.10))
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3.ONE * 0.25
		var tween := ring.create_tween()
		tween.tween_interval(index * 0.08)
		tween.tween_property(ring, "scale", Vector3.ONE * (2.4 + index * 0.35), 0.30)
		tween.parallel().tween_property(ring, "transparency", 1.0, 0.30)
		tween.tween_callback(ring.queue_free)


func spawn_heal_tick() -> void:
	spawn_heal_tick_at(actor.global_position)


func spawn_heal_tick_at(position: Vector3) -> void:
	var cross := Node3D.new()
	cross.name = "NailoongHealCross"
	cross.top_level = true
	cross.add_to_group("transient_combat_vfx")
	cross.add_to_group("nailoong_heal_crosses")
	_world_parent().add_child(cross)
	var active_camera := actor.get_viewport().get_camera_3d()
	var screen_right := Vector3.RIGHT
	if active_camera != null:
		cross.global_basis = active_camera.global_basis.orthonormalized()
		screen_right = active_camera.global_basis.x.normalized()
	var side := -1.0 if actor.visual_rng.randi_range(0, 1) == 0 else 1.0
	cross.global_position = position + screen_right * side * actor.visual_rng.randf_range(0.28, 0.46) + Vector3.UP * actor.visual_rng.randf_range(0.42, 0.64)
	for size in [Vector3(0.30, 0.065, 0.025), Vector3(0.065, 0.30, 0.025)]:
		var part := MeshInstance3D.new()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = _vfx_material(Color(0.32, 1.0, 0.38, 0.76))
		part.mesh = mesh
		cross.add_child(part)
		var fade := part.create_tween()
		fade.tween_interval(0.08)
		fade.tween_property(part, "transparency", 1.0, 0.36)
	var destination := cross.global_position + Vector3.UP * 0.72
	var tween := cross.create_tween()
	tween.tween_property(cross, "global_position", destination, 0.44).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cross, "scale", Vector3.ONE * 1.18, 0.44)
	tween.tween_callback(cross.queue_free)


func _spawn_ring(position: Vector3, inner_radius: float, outer_radius: float, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.top_level = true
	visual.add_to_group("transient_combat_vfx")
	_world_parent().add_child(visual)
	visual.global_position = position
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 40
	mesh.ring_segments = 8
	mesh.material = _vfx_material(color)
	visual.mesh = mesh
	return visual


func _world_parent() -> Node:
	return actor.get_parent() if actor.get_parent() != null else actor


func _vfx_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
