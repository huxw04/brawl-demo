class_name BearVfx
extends Node

## Pure presentation for Bear Grylls. Grapple collision, pull motion, poison
## damage and ambush targeting remain in the authoritative combat layer.

var actor: CombatActor


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func spawn_melee_slash() -> void:
	for index in range(3):
		var slash := MeshInstance3D.new()
		slash.top_level = true
		slash.add_to_group("transient_combat_vfx")
		_world_parent().add_child(slash)
		slash.global_position = actor.global_position + actor.facing * (0.58 + index * 0.10) + Vector3.UP * (0.72 + index * 0.11)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.66 - index * 0.10, 0.025, 0.055)
		mesh.material = _vfx_material(Color(0.88, 0.96, 0.91, 0.72 - index * 0.14))
		slash.mesh = mesh
		slash.rotation.y = atan2(-actor.facing.x, -actor.facing.z)
		slash.rotation.z = -0.50 + index * 0.24
		var tween := slash.create_tween()
		tween.tween_property(slash, "scale:x", 1.65, 0.10)
		tween.parallel().tween_property(slash, "transparency", 1.0, 0.16)
		tween.tween_callback(slash.queue_free)


func spawn_poison_sweep(radius: float) -> void:
	for index in range(5):
		var orbit := Node3D.new()
		orbit.name = "BearWhirlwindOrbit_%d" % index
		orbit.top_level = true
		orbit.add_to_group("transient_combat_vfx")
		_world_parent().add_child(orbit)
		orbit.global_position = Vector3(actor.global_position.x, 0.0, actor.global_position.z)
		var ring_visual := MeshInstance3D.new()
		ring_visual.name = "BearWhiteWhirlwindRing"
		ring_visual.add_to_group("bear_whirlwind_rings")
		ring_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var level := float(index) / 4.0
		var outer_radius := lerpf(radius * 0.34, radius * 0.82, level)
		var ring := TorusMesh.new()
		ring.inner_radius = outer_radius * 0.84
		ring.outer_radius = outer_radius
		ring.rings = 48
		ring.ring_segments = 8
		ring.material = _vfx_material(Color(0.94, 0.98, 1.0, lerpf(0.34, 0.56, level)))
		ring_visual.mesh = ring
		var orbit_radius := lerpf(0.07, 0.20, level)
		ring_visual.position = Vector3(orbit_radius, lerpf(0.46, 1.48, level), 0.0)
		ring_visual.scale = Vector3.ONE * 0.35
		orbit.add_child(ring_visual)
		var direction := -1.0 if index % 2 == 0 else 1.0
		var tween := orbit.create_tween()
		tween.tween_interval(index * 0.025)
		tween.tween_property(ring_visual, "scale", Vector3.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(orbit, "rotation:y", direction * TAU * (1.15 + level * 0.55), 0.38)
		tween.tween_property(ring_visual, "transparency", 1.0, 0.16)
		tween.parallel().tween_property(ring_visual, "scale", Vector3(1.16, 0.35, 1.16), 0.16)
		tween.tween_callback(orbit.queue_free)


func spawn_stealth_puff() -> void:
	for index in range(10):
		var puff := MeshInstance3D.new()
		puff.top_level = true
		puff.add_to_group("transient_combat_vfx")
		_world_parent().add_child(puff)
		var angle := TAU * float(index) / 10.0
		puff.global_position = actor.global_position + Vector3(cos(angle), 0.25 + 0.08 * float(index % 3), sin(angle)) * 0.36
		var mesh := SphereMesh.new()
		mesh.radius = 0.10 + 0.025 * float(index % 2)
		mesh.height = mesh.radius * 2.0
		mesh.material = _vfx_material(Color(0.38, 0.86, 0.62, 0.38))
		puff.mesh = mesh
		var destination := puff.global_position + Vector3(cos(angle), 0.35, sin(angle)) * 0.42
		var tween := puff.create_tween()
		tween.tween_property(puff, "global_position", destination, 0.32)
		tween.parallel().tween_property(puff, "transparency", 1.0, 0.32)
		tween.tween_callback(puff.queue_free)


func spawn_poison_mark(target: CombatActor, duration: float) -> void:
	if target == null:
		return
	var mark := MeshInstance3D.new()
	mark.name = "BearPoisonMark"
	mark.add_to_group("transient_combat_vfx")
	mark.position = Vector3(0.0, target.definition.body_height + 0.34, 0.0)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.25
	ring.rings = 24
	ring.ring_segments = 7
	ring.material = _vfx_material(Color(0.38, 1.0, 0.24, 0.86))
	mark.mesh = ring
	target.add_child(mark)
	var spin := mark.create_tween()
	spin.tween_property(mark, "rotation:y", TAU * 3.0, duration)
	var lifetime := mark.create_tween()
	lifetime.tween_interval(duration * 0.72)
	lifetime.tween_property(mark, "scale", Vector3.ONE * 1.8, duration * 0.28)
	lifetime.parallel().tween_property(mark, "transparency", 1.0, duration * 0.28)
	lifetime.tween_callback(mark.queue_free)


func spawn_poison_burst(target: CombatActor) -> void:
	if target == null:
		return
	var burst := MeshInstance3D.new()
	burst.top_level = true
	burst.add_to_group("transient_combat_vfx")
	_world_parent().add_child(burst)
	burst.global_position = target.global_position + Vector3.UP * 0.82
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.material = _vfx_material(Color(0.35, 1.0, 0.20, 0.62))
	burst.mesh = sphere
	var tween := burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.8, 0.24)
	tween.parallel().tween_property(burst, "transparency", 1.0, 0.24)
	tween.tween_callback(burst.queue_free)


func spawn_backstab_flash(target: CombatActor) -> void:
	for index in range(2):
		var slash := MeshInstance3D.new()
		slash.top_level = true
		slash.add_to_group("transient_combat_vfx")
		_world_parent().add_child(slash)
		slash.global_position = target.global_position + Vector3.UP * (0.76 + index * 0.34)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.62, 0.025, 0.045)
		mesh.material = _vfx_material(Color(1.0, 0.90, 0.42, 0.86))
		slash.mesh = mesh
		slash.rotation.z = -0.72 + index * 1.44
		var tween := slash.create_tween()
		tween.tween_property(slash, "scale:x", 1.8, 0.08)
		tween.parallel().tween_property(slash, "transparency", 1.0, 0.18)
		tween.tween_callback(slash.queue_free)


func spawn_afterimage(position: Vector3, ability: AbilityDefinition) -> void:
	var ghost := Sprite3D.new()
	ghost.top_level = true
	ghost.add_to_group("transient_combat_vfx")
	var action_texture = actor.definition.action_sprite_textures.get(ability.vfx_id)
	ghost.texture = action_texture as Texture2D if action_texture is Texture2D else actor.base_sprite_texture
	ghost.pixel_size = actor.base_sprite_pixel_size
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.modulate = Color(0.68, 0.94, 0.75, 0.46)
	ghost.flip_h = actor.facing.x < -0.05 if actor.definition.sprite_faces_right else actor.facing.x >= -0.05
	_world_parent().add_child(ghost)
	ghost.global_position = position + Vector3.UP * actor.definition.sprite_y
	_set_visual_angle(ghost, 0.0)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "scale", Vector3.ONE * 1.10, 0.24)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ghost.queue_free)


func spawn_teleport_trail(start: Vector3, finish: Vector3, ability: AbilityDefinition) -> void:
	for index in range(1, 5):
		spawn_afterimage(start.lerp(finish, float(index) / 5.0), ability)
	var arrival := MeshInstance3D.new()
	arrival.top_level = true
	arrival.add_to_group("transient_combat_vfx")
	_world_parent().add_child(arrival)
	arrival.global_position = finish + Vector3.UP * 0.08
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.58
	ring.rings = 40
	ring.ring_segments = 8
	ring.material = _vfx_material(Color(0.72, 1.0, 0.76, 0.80))
	arrival.mesh = ring
	var tween := arrival.create_tween()
	tween.tween_property(arrival, "scale", Vector3.ONE * 1.8, 0.22)
	tween.parallel().tween_property(arrival, "transparency", 1.0, 0.22)
	tween.tween_callback(arrival.queue_free)


func spawn_pull_streaks(start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	for index in range(4):
		var streak := MeshInstance3D.new()
		streak.top_level = true
		streak.add_to_group("transient_combat_vfx")
		_world_parent().add_child(streak)
		streak.global_position = start + Vector3.UP * (0.42 + index * 0.26)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.035, minf(direction.length() * 0.44, 1.3))
		mesh.material = _vfx_material(Color(0.66, 0.84, 0.72, 0.48))
		streak.mesh = mesh
		streak.rotation.y = atan2(-direction.normalized().x, -direction.normalized().z)
		var tween := streak.create_tween()
		tween.tween_property(streak, "global_position", streak.global_position + direction.normalized() * 1.1, 0.20)
		tween.parallel().tween_property(streak, "transparency", 1.0, 0.20)
		tween.tween_callback(streak.queue_free)


func _set_visual_angle(sprite: Sprite3D, angle: float) -> void:
	var camera := actor.get_viewport().get_camera_3d()
	if camera == null:
		sprite.rotation.z = angle
		return
	var visual_scale := sprite.scale
	sprite.global_basis = camera.global_basis.orthonormalized() * Basis(Vector3.BACK, angle) * Basis.from_scale(visual_scale)


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
