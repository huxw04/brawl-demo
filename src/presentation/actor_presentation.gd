class_name ActorPresentation
extends Node

## Shared visual replica of a CombatActor. This component may read combat state,
## but never decides ability validity, movement, damage, statuses or death.

const PLACEHOLDER_TEXTURE = preload("res://assets/placeholder_hero.svg")
const ACTION_SWORD_BODY_INSET := 0.30
const WorldStaminaRingScript = preload("res://src/presentation/world_stamina_ring.gd")
const HERO_VFX_SCRIPTS := {
	"nailoong": preload("res://src/presentation/hero_vfx/nailoong_vfx.gd"),
	"chu_ying": preload("res://src/presentation/hero_vfx/chu_ying_vfx.gd"),
	"bear_grylls_jungler": preload("res://src/presentation/hero_vfx/bear_vfx.gd"),
	"sword_shield_dog": preload("res://src/presentation/hero_vfx/sword_shield_vfx.gd"),
	"cheems_samurai": preload("res://src/presentation/hero_vfx/cheems_vfx.gd"),
}

var actor: CombatActor
var sprite: Sprite3D
var shadow_mesh: MeshInstance3D
var name_label: Label3D
var hp_label: Label3D
var energy_label: Label3D
var status_visual: MeshInstance3D
var visual_layer_sprites: Dictionary = {}
var ground_marker: Node3D
var hero_vfx: Node
var stamina_ring: WorldStaminaRing

var visual_motion_time := 0.0
var movement_animation_time := 0.0
var was_visually_moving := false
var death_visual_elapsed := 0.0
var death_fall_side := 1.0
var death_sword_angle := -PI * 0.5
var death_body_start_position := Vector3.ZERO
var death_body_start_scale := Vector3.ONE
var death_layer_start_positions: Dictionary = {}
var death_layer_start_angles: Dictionary = {}
var nailoong_spin_action := ""
var nailoong_spin_phase := 0.0


func setup(p_actor: CombatActor) -> void:
	actor = p_actor
	_create_visual_nodes()
	stamina_ring = WorldStaminaRingScript.new() as WorldStaminaRing
	stamina_ring.name = "WorldStaminaRing"
	actor.add_child(stamina_ring)
	stamina_ring.setup(actor)
	_create_hero_vfx()


func reset_visual() -> void:
	if hero_vfx is CheemsVfx:
		(hero_vfx as CheemsVfx).reset()
	visual_motion_time = 0.0
	movement_animation_time = 0.0
	was_visually_moving = false
	death_visual_elapsed = 0.0
	death_layer_start_positions.clear()
	death_layer_start_angles.clear()
	nailoong_spin_action = ""
	nailoong_spin_phase = 0.0
	sprite.texture = actor.base_sprite_texture
	sprite.pixel_size = actor.base_sprite_pixel_size
	sprite.position = Vector3(0.0, actor.definition.sprite_y, sprite.position.z)
	sprite.scale = Vector3.ONE
	sprite.visible = true
	name_label.visible = true
	hp_label.visible = true
	energy_label.visible = true
	status_visual.visible = true
	ground_marker.visible = true


func begin_action() -> void:
	visual_motion_time = 0.0
	movement_animation_time = 0.0
	was_visually_moving = false


func set_transformed_visual(active: bool) -> void:
	if active:
		sprite.texture = actor.definition.transformed_sprite_texture
		sprite.pixel_size = actor.definition.transformed_sprite_pixel_size if actor.definition.transformed_sprite_pixel_size > 0.0 else actor.base_sprite_pixel_size
	else:
		sprite.texture = actor.base_sprite_texture
		sprite.pixel_size = actor.base_sprite_pixel_size


func spawn_ability_vfx(ability: AbilityDefinition) -> void:
	if ability.vfx_id.is_empty():
		return
	match ability.vfx_id:
		"katana_sweep", "shield_dog_swing", "shield_guard", "shield_dog_heavy_chop", "swole_punch", "swole_dash", "sword_shield_transform", "sword_wave", "multi_slash", "bear_throw_knife", "bear_grapple", "bear_ambush", "dash_slash", "dimensional_slash", "nailoong_leap":
			return
		"shield_bash":
			if hero_vfx is SwordShieldVfx:
				(hero_vfx as SwordShieldVfx).spawn_shield_bash_ghost(ability)
			return
		"bear_melee_knife":
			if hero_vfx is BearVfx:
				(hero_vfx as BearVfx).spawn_melee_slash()
			return
		"bear_poison_mark":
			if hero_vfx is BearVfx:
				(hero_vfx as BearVfx).spawn_poison_sweep(ability.hitbox_radius)
			return
		"bear_stealth":
			if hero_vfx is BearVfx:
				(hero_vfx as BearVfx).spawn_stealth_puff()
			return
		"swole_slam":
			if hero_vfx is SwordShieldVfx:
				(hero_vfx as SwordShieldVfx).spawn_swole_slam_wave(ability)
			return
		"nailoong_tail_sweep":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_tail_sweep(ability.hitbox_radius)
			return
		"nailoong_roll":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_roll_dust()
			return
		"nailoong_fire_breath":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_fire_muzzle()
			return
		"nailoong_laugh":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_laugh_wave()
			return
	var visual := MeshInstance3D.new()
	visual.top_level = true
	actor.get_parent().add_child(visual)
	visual.global_position = Vector3(actor.global_position.x, 0.055, actor.global_position.z) + actor.facing * minf(ability.hitbox_distance, 0.8)
	var mesh := CylinderMesh.new()
	mesh.top_radius = ability.hitbox_radius if ability.hitbox_shape != "box" else maxf(0.35, ability.hitbox_size.x * 0.5)
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.025
	mesh.radial_segments = 40
	mesh.material = _material(Color(ability.color, 0.48), true, true)
	visual.mesh = mesh
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3(1.45, 1.0, 1.45), maxf(0.16, minf(ability.active, 0.45)))
	tween.parallel().tween_property(visual, "transparency", 1.0, maxf(0.16, minf(ability.active, 0.45)))
	tween.tween_callback(visual.queue_free)


func is_one_shot_ability_vfx(ability: AbilityDefinition) -> bool:
	if ability == null or ability.vfx_id.is_empty():
		return false
	return ability.vfx_id not in [
		"katana_sweep", "shield_dog_swing", "shield_guard", "shield_dog_heavy_chop",
		"swole_punch", "swole_dash", "sword_shield_transform", "sword_wave", "multi_slash",
		"bear_throw_knife", "bear_grapple", "bear_ambush", "dash_slash", "dimensional_slash",
		"nailoong_leap", "chu_ying_homing_stone", "chu_ying_falling_stone", "chu_ying_board",
		"chu_ying_teleport", "chu_ying_barrier",
	]


func spawn_concentration_rings(radius: float, duration: float, effect_name: String) -> void:
	var count := maxi(3, ceili(duration / 0.13))
	for index in range(count):
		var ring := MeshInstance3D.new()
		ring.name = effect_name
		ring.top_level = true
		ring.add_to_group("transient_combat_vfx")
		ring.add_to_group("concentration_rings")
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.get_parent().add_child(ring)
		ring.global_position = Vector3(actor.global_position.x, 0.072 + index * 0.002, actor.global_position.z)
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.94
		torus.outer_radius = radius
		torus.rings = 56
		torus.ring_segments = 7
		torus.material = _vfx_material(Color(0.96, 0.99, 1.0, 0.50))
		ring.mesh = torus
		var delay := float(index) * duration / float(count)
		var shrink_duration := minf(0.20, maxf(0.11, duration - delay))
		var tween := ring.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(ring, "scale", Vector3(0.12, 1.0, 0.12), shrink_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(ring, "transparency", 1.0, shrink_duration)
		tween.tween_callback(ring.queue_free)


func update(delta: float) -> void:
	visual_motion_time += delta
	if hero_vfx != null and hero_vfx.has_method("update_continuous_visuals"):
		hero_vfx.call("update_continuous_visuals", delta)
	shadow_mesh.global_position = Vector3(actor.global_position.x, 0.018, actor.global_position.z)
	shadow_mesh.scale = Vector3.ONE * clampf(1.0 - actor.height * 0.09, 0.68, 1.0)
	if actor.is_defeated:
		update_death(delta)
		return
	var facing_left := actor.facing.x < -0.05
	var facing_sign := -1.0 if facing_left else 1.0
	_update_movement_sprite(delta)
	sprite.flip_h = facing_left if actor.definition.sprite_faces_right else not facing_left
	var target_scale := _target_scale()
	var sprite_pose := _current_sprite_pose()
	var pose_scale: Vector2 = sprite_pose["scale"]
	target_scale.x *= pose_scale.x
	target_scale.y *= pose_scale.y
	var dimensional_action := actor.current_ability != null and actor.current_ability.vfx_id == "dimensional_slash"
	var cheems := hero_vfx as CheemsVfx
	if dimensional_action and actor.ability_phase == "active" and cheems != null:
		cheems.update_dimensional_motion(delta, actor.current_ability.hitbox_radius)
	elif cheems != null:
		cheems.relax_dimensional_motion(delta)
	var dimensional_offset := cheems.visual_offset if cheems != null else Vector3.ZERO
	var pose_offset: Vector2 = sprite_pose["offset"]
	sprite.position.x = dimensional_offset.x + pose_offset.x * facing_sign
	sprite.position.y = actor.definition.sprite_y + pose_offset.y
	sprite.position.z = dimensional_offset.z
	sprite.scale = sprite.scale.lerp(target_scale, minf(1.0, delta * 15.0))
	var visual_angle := float(sprite_pose["angle"]) * facing_sign
	var nailoong_rolling := actor.current_ability != null and actor.current_ability.vfx_id == "nailoong_roll" and actor.ability_phase == "active"
	var next_spin_action := ""
	if nailoong_rolling:
		next_spin_action = "roll"
	elif actor.current_ability != null and actor.current_ability.vfx_id == "nailoong_tail_sweep":
		next_spin_action = "tail"
	if next_spin_action != nailoong_spin_action:
		nailoong_spin_action = next_spin_action
		nailoong_spin_phase = 0.0
	if nailoong_rolling:
		nailoong_spin_phase = fmod(nailoong_spin_phase + delta * 10.5, TAU)
		visual_angle += nailoong_spin_phase * facing_sign
	elif next_spin_action == "tail":
		var spin_speed := TAU / maxf(actor.current_ability.total_duration(), 0.01)
		nailoong_spin_phase = minf(TAU, nailoong_spin_phase + delta * spin_speed)
		visual_angle += nailoong_spin_phase * facing_sign
	set_visual_layer_angle(sprite, visual_angle)
	_update_visibility_and_status(delta)
	_update_visual_layers()


func begin_death() -> void:
	death_visual_elapsed = 0.0
	if actor.definition.hero_id == "bear_grylls_jungler":
		sprite.texture = actor.base_sprite_texture
		sprite.position = Vector3(0.0, actor.definition.sprite_y, sprite.position.z)
		sprite.scale = Vector3.ONE
	death_fall_side = -1.0 if actor.visual_rng.randi_range(0, 1) == 0 else 1.0
	var facing_sign := -1.0 if actor.facing.x < -0.05 else 1.0
	death_sword_angle = -facing_sign * PI * 0.5
	death_body_start_position = sprite.position
	death_body_start_scale = sprite.scale
	death_layer_start_positions.clear()
	death_layer_start_angles.clear()
	for layer_id in visual_layer_sprites.keys():
		var layer_sprite := visual_layer_sprites.get(layer_id) as Sprite3D
		if layer_sprite == null:
			continue
		death_layer_start_positions[layer_id] = layer_sprite.position
		death_layer_start_angles[layer_id] = float(layer_sprite.get_meta("visual_angle", 0.0))
	ground_marker.visible = false
	name_label.visible = false
	hp_label.visible = false
	energy_label.visible = false
	status_visual.visible = false


func update_death(delta: float) -> void:
	death_visual_elapsed += delta
	var progress := clampf(death_visual_elapsed / 0.52, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	sprite.visible = true
	sprite.position = death_body_start_position.lerp(Vector3(death_fall_side * 0.20, 0.38, death_body_start_position.z), eased)
	set_visual_layer_angle(sprite, death_fall_side * PI * 0.5 * eased)
	sprite.scale = death_body_start_scale.lerp(Vector3(1.04, 0.94, 1.0), eased)
	shadow_mesh.scale = Vector3.ONE * lerpf(1.0, 1.28, eased)
	for layer_id_value in visual_layer_sprites.keys():
		var layer_id := str(layer_id_value)
		var layer_sprite := visual_layer_sprites.get(layer_id) as Sprite3D
		if layer_sprite == null:
			continue
		var start_position: Vector3 = death_layer_start_positions.get(layer_id, layer_sprite.position)
		var start_angle := float(death_layer_start_angles.get(layer_id, 0.0))
		match layer_id:
			"hat":
				layer_sprite.visible = true
				layer_sprite.position = start_position.lerp(Vector3(start_position.x + death_fall_side * 0.46, 0.14, start_position.z), eased)
				set_visual_layer_angle(layer_sprite, lerpf(start_angle, death_fall_side * 1.35, eased))
			"scabbard_back":
				layer_sprite.visible = true
				layer_sprite.position = start_position.lerp(Vector3(start_position.x - death_fall_side * 0.34, 0.12, start_position.z), eased)
				set_visual_layer_angle(layer_sprite, lerpf(start_angle, death_fall_side * 0.12, eased))
			"katana_back":
				layer_sprite.visible = false
			"katana_action":
				layer_sprite.visible = true
				layer_sprite.position = start_position.lerp(Vector3(death_fall_side * 0.42, 0.82, start_position.z), eased)
				set_visual_layer_angle(layer_sprite, lerpf(start_angle, death_sword_angle, eased))
			_:
				layer_sprite.visible = false


func set_visual_layer_angle(layer_sprite: Sprite3D, angle: float) -> void:
	layer_sprite.set_meta("visual_angle", angle)
	var active_camera := actor.get_viewport().get_camera_3d()
	if active_camera == null:
		layer_sprite.rotation.z = angle
		return
	var visual_scale := layer_sprite.scale
	var camera_basis := active_camera.global_basis.orthonormalized()
	layer_sprite.global_basis = camera_basis * Basis(Vector3.BACK, angle) * Basis.from_scale(visual_scale)


func relation_color() -> Color:
	match actor.relation:
		CombatActor.Relation.SELF:
			return Color("54db72")
		CombatActor.Relation.ALLY:
			return Color("58a8ff")
		_:
			return Color("ef5f5f")


func _create_hero_vfx() -> void:
	var script = HERO_VFX_SCRIPTS.get(actor.definition.hero_id)
	if script == null:
		return
	hero_vfx = script.new() as Node
	hero_vfx.name = "%sVfx" % actor.definition.hero_id.to_pascal_case()
	add_child(hero_vfx)
	hero_vfx.call("setup", actor)


func _create_visual_nodes() -> void:
	shadow_mesh = MeshInstance3D.new()
	shadow_mesh.name = "GroundShadow"
	shadow_mesh.top_level = true
	var shadow := CylinderMesh.new()
	shadow.top_radius = actor.definition.body_radius * 1.15
	shadow.bottom_radius = actor.definition.body_radius * 1.15
	shadow.height = 0.018
	shadow.radial_segments = 32
	shadow.material = _material(Color(0.01, 0.02, 0.03, 0.38), true, true)
	shadow_mesh.mesh = shadow
	shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor.add_child(shadow_mesh)

	sprite = Sprite3D.new()
	sprite.name = "CharacterSprite2D"
	sprite.texture = actor.definition.sprite_texture if actor.definition.sprite_texture != null else PLACEHOLDER_TEXTURE
	sprite.pixel_size = actor.definition.sprite_pixel_size
	sprite.position.y = actor.definition.sprite_y
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.modulate = Color.WHITE
	actor.add_child(sprite)

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	actor.add_child(animation_player)

	name_label = Label3D.new()
	name_label.text = actor.actor_name
	name_label.position.y = actor.definition.body_height + 0.68
	name_label.font_size = 32
	name_label.pixel_size = 0.007
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.modulate = Color("e8f4fb")
	actor.add_child(name_label)
	hp_label = Label3D.new()
	hp_label.position.y = actor.definition.body_height + 0.43
	hp_label.font_size = 30
	hp_label.pixel_size = 0.0065
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label.no_depth_test = true
	hp_label.outline_size = 7
	hp_label.modulate = relation_color()
	actor.add_child(hp_label)
	energy_label = Label3D.new()
	energy_label.position.y = actor.definition.body_height + 0.25
	energy_label.font_size = 25
	energy_label.pixel_size = 0.0058
	energy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	energy_label.no_depth_test = true
	energy_label.outline_size = 6
	energy_label.modulate = actor.definition.status_bar_color
	actor.add_child(energy_label)
	_create_visual_layers()
	status_visual = MeshInstance3D.new()
	var status_ring := TorusMesh.new()
	status_ring.inner_radius = actor.definition.body_radius * 0.92
	status_ring.outer_radius = actor.definition.body_radius * 1.05
	status_ring.rings = 28
	status_ring.ring_segments = 6
	status_visual.mesh = status_ring
	status_visual.position.y = 0.045
	status_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actor.add_child(status_visual)
	_create_ground_marker()


func _create_ground_marker() -> void:
	ground_marker = Node3D.new()
	ground_marker.name = "GroundRelationMarker"
	ground_marker.top_level = true
	var color := relation_color()
	var ring_instance := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = actor.definition.body_radius * 1.22
	ring.outer_radius = actor.definition.body_radius * 1.38
	ring.rings = 32
	ring.ring_segments = 8
	ring.material = _material(Color(color, 0.92), true, true)
	ring_instance.mesh = ring
	ring_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_marker.add_child(ring_instance)
	var arrow_instance := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(color)
	surface.add_vertex(Vector3(0.0, 0.018, -actor.definition.body_radius * 1.95))
	surface.add_vertex(Vector3(-0.16, 0.018, -actor.definition.body_radius * 1.35))
	surface.add_vertex(Vector3(0.16, 0.018, -actor.definition.body_radius * 1.35))
	var arrow_mesh := surface.commit()
	arrow_mesh.surface_set_material(0, _material(color, false, true))
	arrow_instance.mesh = arrow_mesh
	arrow_instance.scale = Vector3(1.45, 1.0, 1.45)
	arrow_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_marker.add_child(arrow_instance)
	actor.add_child(ground_marker)


func _create_visual_layers() -> void:
	for layer in actor.definition.visual_layers:
		if layer == null or layer.texture == null:
			continue
		var layer_sprite := Sprite3D.new()
		layer_sprite.name = "VisualLayer_%s" % layer.layer_id
		layer_sprite.texture = layer.texture
		layer_sprite.pixel_size = layer.pixel_size
		layer_sprite.position = Vector3(layer.offset.x, layer.offset.y, float(layer.render_priority) * 0.025)
		layer_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		layer_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		layer_sprite.offset = layer.texture_offset
		layer_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer_sprite.sorting_offset = float(layer.render_priority) * 0.01
		if layer.remove_light_neutral_background:
			layer_sprite.material_override = _light_neutral_key_material(layer.texture)
		actor.add_child(layer_sprite)
		visual_layer_sprites[layer.layer_id] = layer_sprite


func _target_scale() -> Vector3:
	var nailoong_rolling := actor.current_ability != null and actor.current_ability.vfx_id == "nailoong_roll" and actor.ability_phase == "active"
	if nailoong_rolling:
		return Vector3(0.84, 0.84, 1.0)
	if actor.current_ability != null and actor.current_ability.vfx_id == "nailoong_laugh" and actor.ability_phase == "startup":
		var laugh_bounce := sin(actor.action_elapsed * TAU * 5.0)
		return Vector3(1.0 + laugh_bounce * 0.08, 1.0 - laugh_bounce * 0.08, 1.0)
	if actor.transformed and actor.current_ability != null and actor.current_ability.vfx_id == "swole_dash" and actor.ability_phase == "active":
		return Vector3(1.30, 0.88, 1.0)
	if actor.transformed:
		return Vector3(1.08, 1.08, 1.0)
	if actor.roll_remaining > 0.0:
		return Vector3(1.28, 0.72, 1.0)
	if actor.ability_phase == "startup" and not (actor.current_ability != null and actor.current_ability.vfx_id == "dimensional_slash"):
		return Vector3(0.92, 1.08, 1.0)
	if actor.ability_phase == "active":
		return Vector3(1.18, 0.9, 1.0)
	return Vector3.ONE


func _update_visibility_and_status(delta: float) -> void:
	var base_color := Color.WHITE
	if actor.status_controller.has_visual("slow"):
		base_color = base_color.lerp(Color("74cfff"), 0.28)
	elif actor.status_controller.has_visual("poison"):
		base_color = base_color.lerp(Color("8be35a"), 0.32)
	if actor.spawn_protection_remaining > 0.0:
		base_color = base_color.lerp(Color("bdefff"), 0.38)
	if actor.status_controller.has_tag("untargetable"):
		base_color.a = 0.34
	var stealthed := actor.status_controller.has_tag("stealth")
	var hidden_from_local_view := stealthed and actor.relation != CombatActor.Relation.SELF
	if stealthed and actor.relation == CombatActor.Relation.SELF:
		base_color.a = minf(base_color.a, 0.20)
	sprite.modulate = Color.WHITE if actor.flash_remaining > 0.0 else base_color
	sprite.visible = not hidden_from_local_view
	shadow_mesh.visible = not hidden_from_local_view
	ground_marker.global_position = Vector3(actor.global_position.x, 0.05, actor.global_position.z)
	ground_marker.rotation.y = atan2(-actor.facing.x, -actor.facing.z)
	ground_marker.visible = not hidden_from_local_view
	var overhead := "复活保护" if actor.spawn_protection_remaining > 0.0 else actor.status_controller.overhead_text()
	name_label.text = overhead if not overhead.is_empty() else actor.actor_name
	name_label.modulate = Color("ffe29a") if not overhead.is_empty() else Color("e8f4fb")
	var hp_segments := maxi(1, ceili(actor.definition.max_hp / 10.0))
	var filled := clampi(ceili(actor.hp / 10.0), 0, hp_segments)
	hp_label.text = "▰".repeat(filled) + "▱".repeat(hp_segments - filled)
	var has_status_resource := actor.definition.max_energy > 0.0 and not actor.definition.status_bar_id.is_empty()
	if has_status_resource:
		var energy_filled := clampi(ceili((actor.energy / actor.definition.max_energy) * 12.0), 0, 12)
		energy_label.text = "▰".repeat(energy_filled) + "▱".repeat(12 - energy_filled)
	else:
		energy_label.text = ""
	name_label.visible = not hidden_from_local_view
	hp_label.visible = not hidden_from_local_view
	energy_label.visible = has_status_resource and not hidden_from_local_view
	var visual_color := Color(0.3, 0.8, 1.0, 0.0)
	if actor.status_controller.has_visual("slow"):
		visual_color = Color("62cfff")
	elif actor.status_controller.has_visual("poison"):
		visual_color = Color("78d84e")
	elif actor.status_controller.has_tag("control_immune"):
		visual_color = Color("ffd45b")
	status_visual.visible = visual_color.a > 0.0 and not hidden_from_local_view
	if status_visual.visible:
		(status_visual.mesh as TorusMesh).material = _material(Color(visual_color, 0.78), true, true)
		status_visual.rotation.y += delta * 2.4


func _update_movement_sprite(delta: float) -> void:
	if actor.transformed:
		was_visually_moving = false
		return
	if actor.definition.hero_id == "bear_grylls_jungler" and actor.bear_grapple_pull_remaining > 0.0:
		movement_animation_time = 0.0
		was_visually_moving = false
		var pull_texture = actor.definition.action_sprite_textures.get("bear_grapple")
		sprite.texture = pull_texture as Texture2D if pull_texture is Texture2D else actor.base_sprite_texture
		return
	if actor.current_ability != null:
		movement_animation_time = 0.0
		was_visually_moving = false
		var action_key := "bear_throw_knife" if actor.current_ability.vfx_id == "bear_grapple" else actor.current_ability.vfx_id
		var action_texture = actor.definition.action_sprite_textures.get(action_key)
		sprite.texture = action_texture as Texture2D if action_texture is Texture2D else actor.base_sprite_texture
		return
	var moving := actor.roll_remaining <= 0.0 and actor.move_intent.length_squared() > 0.01 and actor.is_visually_grounded()
	if not moving or actor.definition.movement_sprite_textures.is_empty():
		movement_animation_time = 0.0
		was_visually_moving = false
		sprite.texture = actor.base_sprite_texture
		return
	if not was_visually_moving:
		movement_animation_time = 0.0
	else:
		movement_animation_time += delta
	was_visually_moving = true
	var durations := actor.definition.movement_sprite_frame_durations
	var total_duration := 0.0
	for index in range(actor.definition.movement_sprite_textures.size()):
		total_duration += durations[index] if index < durations.size() else 0.12
	if total_duration <= 0.0:
		sprite.texture = actor.definition.movement_sprite_textures[0]
		return
	var local_time := fmod(movement_animation_time, total_duration)
	for index in range(actor.definition.movement_sprite_textures.size()):
		var frame_duration := durations[index] if index < durations.size() else 0.12
		if local_time < frame_duration:
			sprite.texture = actor.definition.movement_sprite_textures[index]
			return
		local_time -= frame_duration
	sprite.texture = actor.definition.movement_sprite_textures.back()


func _current_sprite_pose() -> Dictionary:
	var neutral := {"offset": Vector2.ZERO, "scale": Vector2.ONE, "angle": 0.0}
	if not actor.transformed:
		return neutral
	var clip_id := ""
	var clip_time := 0.0
	if actor.current_ability != null and actor.current_ability.vfx_id == "swole_punch":
		clip_id = "transformed_basic"
		clip_time = actor.action_elapsed
	elif actor.current_ability != null and actor.current_ability.vfx_id == "swole_slam":
		clip_id = "transformed_slam"
		clip_time = actor.action_elapsed
	elif actor.current_ability == null and actor.move_intent.length_squared() > 0.01 and actor.is_visually_grounded():
		clip_id = "transformed_walk"
		clip_time = visual_motion_time
	var clip = actor.definition.sprite_pose_clips.get(clip_id)
	return clip.call("sample", clip_time) if clip != null and clip.has_method("sample") else neutral


func _update_visual_layers() -> void:
	var action_id := actor.current_ability.ability_id if actor.current_ability != null else ""
	var facing_left := actor.facing.x < -0.05
	if hero_vfx is SwordShieldVfx:
		(hero_vfx as SwordShieldVfx).update_layers(action_id, facing_left)
		return
	var action_sword_active := action_id in ["basic", "skill_q", "skill_w", "skill_e", "ultimate"]
	var phase_progress := _visual_phase_progress()
	for layer in actor.definition.visual_layers:
		var layer_sprite := visual_layer_sprites.get(layer.layer_id) as Sprite3D
		if layer_sprite == null:
			continue
		var facing_sign := -1.0 if facing_left else 1.0
		var mirror_texture := facing_left if actor.definition.sprite_faces_right else not facing_left
		layer_sprite.flip_h = mirror_texture
		layer_sprite.position.x = layer.offset.x * facing_sign
		layer_sprite.position.y = layer.offset.y
		layer_sprite.position.z = float(layer.render_priority) * 0.025
		layer_sprite.offset.x = -layer.texture_offset.x if mirror_texture else layer.texture_offset.x
		layer_sprite.offset.y = layer.texture_offset.y
		set_visual_layer_angle(layer_sprite, layer.base_rotation * facing_sign)
		var visible := layer.visible_by_default
		if layer.layer_id == "katana_back":
			visible = not actor.weapon_drawn and not action_sword_active
		elif layer.layer_id == "katana_action":
			visible = actor.weapon_drawn or action_sword_active
		else:
			if not layer.show_during_actions.is_empty():
				visible = layer.show_during_actions.has(action_id)
			if layer.hide_during_actions.has(action_id):
				visible = false
		layer_sprite.visible = visible and not actor.is_defeated
		var cheems := hero_vfx as CheemsVfx
		var dimensional_offset := cheems.visual_offset if cheems != null else Vector3.ZERO
		layer_sprite.position.x += dimensional_offset.x
		layer_sprite.position.z += dimensional_offset.z
		layer_sprite.modulate = Color.WHITE
		if actor.status_controller.has_tag("untargetable") and layer.layer_id != "katana_action":
			layer_sprite.modulate.a = 0.26
		if layer.remove_light_neutral_background and layer_sprite.material_override is ShaderMaterial:
			(layer_sprite.material_override as ShaderMaterial).set_shader_parameter("opacity", layer_sprite.modulate.a)
		if layer.layer_id == "katana_action" and layer_sprite.visible:
			_update_cheems_katana(layer_sprite, action_id, facing_sign, phase_progress)


func _update_cheems_katana(layer_sprite: Sprite3D, action_id: String, facing_sign: float, phase_progress: float) -> void:
	layer_sprite.scale = Vector3.ONE
	var visual_time := actor.action_elapsed
	if action_id in ["skill_w", "skill_e", "ultimate"]:
		layer_sprite.position.x -= facing_sign * ACTION_SWORD_BODY_INSET
	match action_id:
		"basic":
			if actor.basic_combo_step == 0:
				if actor.ability_phase == "startup":
					set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-1.50, -2.05, phase_progress))
					layer_sprite.position.x = facing_sign * lerpf(0.16, 0.48, phase_progress)
					layer_sprite.position.y = lerpf(0.94, 1.26, phase_progress)
				else:
					set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-2.05, 0.82, phase_progress if actor.ability_phase == "active" else 1.0))
					layer_sprite.position.x += facing_sign * 0.25
			elif actor.basic_combo_step == 1:
				set_visual_layer_angle(layer_sprite, facing_sign * lerpf(0.92, -1.18, phase_progress if actor.ability_phase == "active" else 0.0))
				layer_sprite.position.x += facing_sign * 0.32
			else:
				set_visual_layer_angle(layer_sprite, facing_sign * 0.02)
				layer_sprite.position.x += facing_sign * lerpf(0.20, 0.86, phase_progress if actor.ability_phase == "active" else 0.15)
				layer_sprite.scale.x = lerpf(0.88, 1.22, phase_progress if actor.ability_phase == "active" else 0.0)
		"skill_q":
			set_visual_layer_angle(layer_sprite, facing_sign * lerpf(0.62, -1.28, phase_progress))
			layer_sprite.position.x += facing_sign * lerpf(0.18, 0.62, phase_progress)
			layer_sprite.position.y += lerpf(-0.06, 0.38, phase_progress)
		"skill_w":
			set_visual_layer_angle(layer_sprite, facing_sign * sin(visual_time * 34.0) * 0.34)
			layer_sprite.position.x += facing_sign * 0.58
			layer_sprite.scale.x = 0.72 + absf(sin(visual_time * 34.0)) * 0.78
		"skill_e":
			set_visual_layer_angle(layer_sprite, facing_sign * 0.02)
			layer_sprite.position.x += facing_sign * 0.86
			layer_sprite.scale.x = 1.20
		"ultimate":
			if actor.ability_phase == "startup":
				set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-1.50, -2.02, phase_progress))
				layer_sprite.position.y += lerpf(0.0, 0.38, phase_progress)
			elif actor.ability_phase == "active":
				set_visual_layer_angle(layer_sprite, facing_sign * sin(visual_time * 38.0) * 0.42)
				layer_sprite.position.x += facing_sign * sin(visual_time * 27.0) * 0.92
				layer_sprite.scale.x = 1.30
		_:
			set_visual_layer_angle(layer_sprite, facing_sign * -0.34)
			layer_sprite.position.x += facing_sign * 0.18


func _visual_phase_progress() -> float:
	if actor.current_ability == null:
		return 0.0
	var duration := actor.current_ability.startup
	if actor.ability_phase == "active":
		duration = actor.current_ability.active
	elif actor.ability_phase == "recovery":
		duration = actor.current_ability.recovery
	return clampf(1.0 - actor.phase_remaining / maxf(duration, 0.001), 0.0, 1.0)


func _light_neutral_key_material(texture: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform float opacity = 1.0;
void fragment() {
	vec4 c = texture(source_texture, UV);
	float high = max(c.r, max(c.g, c.b));
	float low = min(c.r, min(c.g, c.b));
	float saturation = high - low;
	float colored = smoothstep(0.055, 0.14, saturation);
	float dark_detail = 1.0 - smoothstep(0.68, 0.86, high);
	float keep = max(colored, dark_detail);
	ALBEDO = c.rgb;
	ALPHA = c.a * keep * opacity;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("source_texture", texture)
	return material


func _material(color: Color, transparent := false, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _vfx_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, true, true)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
