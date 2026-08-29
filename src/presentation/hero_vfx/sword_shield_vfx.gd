class_name SwordShieldVfx
extends Node

## Pure presentation for the sword-and-shield dog. Ability validation,
## hitboxes, knockback, delayed damage and transformation state remain on the
## authoritative combat actor.

var actor: CombatActor


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func spawn_swole_slam_wave(ability: AbilityDefinition) -> void:
	var wave := MeshInstance3D.new()
	wave.name = "SwoleSlamShockwave"
	wave.top_level = true
	wave.add_to_group("transient_combat_vfx")
	_world_parent().add_child(wave)
	wave.global_position = Vector3(actor.global_position.x, 0.08, actor.global_position.z)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 1.0
	ring.rings = 56
	ring.ring_segments = 8
	ring.material = _vfx_material(Color(0.92, 0.97, 1.0, 0.58))
	wave.mesh = ring
	wave.scale = Vector3(0.22, 1.0, 0.22)
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3(ability.hitbox_radius, 0.20, ability.hitbox_radius), 0.30)
	tween.parallel().tween_property(wave, "transparency", 1.0, 0.30)
	tween.tween_callback(wave.queue_free)


func spawn_shield_bash_ghost(ability: AbilityDefinition) -> void:
	var source_shield := actor.visual_layer_sprites.get("shield_dog_shield") as Sprite3D
	if source_shield == null:
		return
	var ghost := Sprite3D.new()
	ghost.name = "ShieldBashGhost"
	ghost.top_level = true
	ghost.add_to_group("transient_combat_vfx")
	ghost.texture = source_shield.texture
	ghost.pixel_size = source_shield.pixel_size
	ghost.offset = source_shield.offset
	ghost.flip_h = actor.facing.x < -0.05
	if ghost.flip_h:
		ghost.offset.x = -ghost.offset.x
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.modulate = Color(0.78, 0.91, 1.0, 0.60)
	ghost.set_meta("initial_opacity", ghost.modulate.a)
	_world_parent().add_child(ghost)
	var direction := actor.facing.normalized()
	var start := actor.global_position + direction * 0.26 + Vector3.UP * 0.86
	var finish := actor.global_position + direction * (ability.hitbox_distance + ability.hitbox_size.z * 0.5) + Vector3.UP * 0.86
	ghost.global_position = start
	var active_camera := actor.get_viewport().get_camera_3d()
	var facing_sign := -1.0 if ghost.flip_h else 1.0
	var ghost_scale := Vector3.ONE * 2.45
	if active_camera != null:
		ghost.global_basis = active_camera.global_basis.orthonormalized() * Basis(Vector3.BACK, facing_sign * -0.06) * Basis.from_scale(ghost_scale)
	else:
		ghost.rotation.z = facing_sign * -0.06
		ghost.scale = ghost_scale
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "global_position", finish, maxf(ability.active, 0.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, maxf(ability.active, 0.12))
	tween.tween_callback(ghost.queue_free)


func spawn_block_flash() -> void:
	var visual := MeshInstance3D.new()
	visual.top_level = true
	visual.add_to_group("transient_combat_vfx")
	_world_parent().add_child(visual)
	visual.global_position = actor.global_position + actor.facing * 0.55 + Vector3.UP * 0.85
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.material = _vfx_material(Color(0.72, 0.9, 1.0, 0.8))
	visual.mesh = mesh
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 2.2, 0.12)
	tween.parallel().tween_property(visual, "transparency", 1.0, 0.12)
	tween.tween_callback(visual.queue_free)


func update_layers(action_id: String, facing_left: bool) -> void:
	var facing_sign := -1.0 if facing_left else 1.0
	var mirror_texture := facing_left if actor.definition.sprite_faces_right else not facing_left
	var progress := _visual_phase_progress()
	for layer in actor.definition.visual_layers:
		var layer_sprite := actor.visual_layer_sprites.get(layer.layer_id) as Sprite3D
		if layer_sprite == null:
			continue
		layer_sprite.flip_h = mirror_texture
		layer_sprite.offset.x = -layer.texture_offset.x if mirror_texture else layer.texture_offset.x
		layer_sprite.offset.y = layer.texture_offset.y
		layer_sprite.position = Vector3(layer.offset.x * facing_sign, layer.offset.y, float(layer.render_priority) * 0.025)
		layer_sprite.scale = Vector3.ONE
		layer_sprite.modulate = Color.WHITE
		_set_visual_layer_angle(layer_sprite, layer.base_rotation * facing_sign)
		layer_sprite.visible = not actor.transformed and not actor.is_defeated
		if not layer_sprite.visible:
			continue
		if action_id == "ultimate" and actor.ability_phase == "startup":
			layer_sprite.position.x = lerpf(layer_sprite.position.x, 0.0, progress)
			layer_sprite.position.y = lerpf(layer_sprite.position.y, 1.48, progress)
			layer_sprite.scale = Vector3.ONE * lerpf(1.0, 0.08, progress)
			_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(layer.base_rotation, 2.4, progress))
		elif layer.layer_id == "shield_dog_sword":
			_update_sword_layer(layer_sprite, layer, action_id, facing_sign, progress)
		else:
			_update_shield_layer(layer_sprite, layer, action_id, facing_sign, progress)


func _update_sword_layer(layer_sprite: Sprite3D, layer, action_id: String, facing_sign: float, progress: float) -> void:
	match action_id:
		"basic":
			layer_sprite.position.x += facing_sign * 0.08
			layer_sprite.position.y += 0.08
			if actor.ability_phase == "startup":
				_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(layer.base_rotation, 1.18, progress))
			elif actor.ability_phase == "active":
				_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(1.18, -0.58, progress))
			else:
				var return_progress := clampf((progress - 0.55) / 0.45, 0.0, 1.0)
				_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-0.58, layer.base_rotation, return_progress))
		"skill_w":
			layer_sprite.position.x += facing_sign * 0.06
			if actor.ability_phase == "startup":
				layer_sprite.scale = Vector3(lerpf(1.0, 2.25, progress), lerpf(1.0, 1.28, progress), 1.0)
				_set_visual_layer_angle(layer_sprite, facing_sign * layer.base_rotation)
			elif actor.ability_phase == "active":
				var chop_progress := clampf(progress / 0.72, 0.0, 1.0)
				layer_sprite.scale = Vector3(2.25, 1.28, 1.0)
				_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(1.52, -0.62, chop_progress))
			else:
				layer_sprite.scale = Vector3.ONE
				_set_visual_layer_angle(layer_sprite, facing_sign * layer.base_rotation)


func _update_shield_layer(layer_sprite: Sprite3D, layer, action_id: String, facing_sign: float, progress: float) -> void:
	match action_id:
		"skill_q":
			layer_sprite.position.x = facing_sign * 0.58
			layer_sprite.position.y = 0.88
			layer_sprite.scale = Vector3.ONE * 1.16
			_set_visual_layer_angle(layer_sprite, facing_sign * -0.06)
		"skill_e":
			layer_sprite.position.y = 0.86
			if actor.ability_phase == "startup":
				layer_sprite.position.x = facing_sign * lerpf(absf(layer.offset.x), 0.50, progress)
				layer_sprite.scale = Vector3.ONE * lerpf(1.0, 1.30, progress)
			elif actor.ability_phase == "active":
				var push_progress := clampf(progress / 0.48, 0.0, 1.0)
				layer_sprite.position.x = facing_sign * lerpf(0.50, 0.78, push_progress)
				layer_sprite.scale = Vector3.ONE * 1.30
			else:
				var return_progress := clampf((progress - 0.45) / 0.55, 0.0, 1.0)
				layer_sprite.position.x = facing_sign * lerpf(0.78, absf(layer.offset.x), return_progress)
				layer_sprite.scale = Vector3.ONE * lerpf(1.30, 1.0, return_progress)


func _visual_phase_progress() -> float:
	if actor.current_ability == null:
		return 0.0
	var duration := actor.current_ability.startup
	if actor.ability_phase == "active":
		duration = actor.current_ability.active
	elif actor.ability_phase == "recovery":
		duration = actor.current_ability.recovery
	return clampf(1.0 - actor.phase_remaining / maxf(duration, 0.001), 0.0, 1.0)


func _set_visual_layer_angle(layer_sprite: Sprite3D, angle: float) -> void:
	layer_sprite.set_meta("visual_angle", angle)
	var active_camera := actor.get_viewport().get_camera_3d()
	if active_camera == null:
		layer_sprite.rotation.z = angle
		return
	var visual_scale := layer_sprite.scale
	var camera_basis := active_camera.global_basis.orthonormalized()
	layer_sprite.global_basis = camera_basis * Basis(Vector3.BACK, angle) * Basis.from_scale(visual_scale)


func _world_parent() -> Node:
	return actor.get_parent()


func _vfx_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
