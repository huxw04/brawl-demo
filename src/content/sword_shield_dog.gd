class_name SwordShieldDog
extends RefCounted

const PoseClipScript = preload("res://src/presentation/sprite_pose_clip.gd")


static func create() -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.hero_id = "sword_shield_dog"
	hero.display_name = "刀盾狗"
	hero.theme_color = Color("b9854e")
	hero.max_hp = 180.0
	hero.move_speed = 3.35
	hero.max_energy = 0.0
	hero.status_bar_id = ""
	hero.status_bar_label = ""
	hero.body_radius = 0.43
	hero.body_height = 1.48
	hero.sprite_texture = load("res://assets/heroes/sword_shield_dog/sprites/sword_shield_dog_body_v1.png")
	hero.sprite_pixel_size = 0.00105
	hero.sprite_y = 0.77
	hero.sprite_faces_right = true
	hero.transformed_sprite_texture = load("res://assets/heroes/sword_shield_dog/sprites/sword_shield_dog_swole_v1.png")
	hero.transformed_sprite_pixel_size = 0.00170
	hero.transform_duration = 8.0
	hero.transformed_move_speed_multiplier = 1.2
	_configure_layers(hero)
	_configure_pose_clips(hero)

	var basic := _ability("basic", "短刀挥砍", 0.12, 0.10, 0.24, 0.52)
	basic.damage = 11.0
	basic.knockback = 0.0
	basic.hitbox_shape = "arc"
	basic.hitbox_radius = 1.80
	basic.arc_degrees = 150.0
	basic.hitbox_center_y = 0.66
	basic.auto_target_radius = 1.94
	basic.energy_on_hit = 0.0
	basic.vfx_id = "shield_dog_swing"

	var q := _ability("skill_q", "正面格挡", 0.08, 0.10, 0.08, 2.0)
	q.damage = 0.0
	q.spawns_attack = false
	q.requires_aim_confirmation = false
	q.hold_to_channel = true
	q.minimum_hold_duration = 0.5
	q.cancelable_by_movement = true
	q.locks_movement = true
	q.blocks_front_damage = true
	q.front_block_degrees = 120.0
	q.vfx_id = "shield_guard"

	var w := _ability("skill_w", "蓄力重劈", 0.5, 0.14, 0.0, 8.0)
	w.damage = 15.0
	w.knockback = 0.0
	w.hitbox_size = Vector3(2.35, 1.35, 2.90)
	w.hitbox_distance = 1.38
	w.hitbox_center_y = 0.70
	w.delayed_damage = 20.0
	w.delayed_delay = 1.5
	w.delayed_radius = 1.65
	w.delayed_center_distance = 1.38
	w.locks_movement = true
	w.self_control_immune_duration = 0.62
	w.startup_slow_duration = 0.5
	w.vfx_id = "shield_dog_heavy_chop"
	w.energy_on_hit = 0.0
	w.targeting_preview = "box"
	w.targeting_preview_secondary_radius = w.delayed_radius

	var e := _ability("skill_e", "盾牌猛击", 0.12, 0.18, 0.12, 6.0)
	e.damage = 8.0
	e.knockback = 4.8
	e.hitbox_size = Vector3(2.10, 1.25, 1.65)
	e.hitbox_distance = 0.92
	e.hitbox_center_y = 0.68
	e.apply_stun_duration = 1.0
	e.apply_stun_delay = 0.12
	e.vfx_id = "shield_bash"
	e.energy_on_hit = 0.0
	e.targeting_preview = "box"

	var r := _ability("ultimate", "肌肉觉醒", 0.62, 0.05, 0.20, 30.0)
	r.energy_cost = 0.0
	r.damage = 0.0
	r.spawns_attack = false
	r.requires_aim_confirmation = false
	r.cooldown_on_form_end = true
	r.vfx_id = "sword_shield_transform"

	var form_basic := _ability("basic", "肌肉重拳", 0.10, 0.12, 0.20, 0.48)
	form_basic.damage = 19.0
	form_basic.knockback = 0.0
	form_basic.hitbox_shape = "arc"
	form_basic.hitbox_radius = 2.80
	form_basic.arc_degrees = 180.0
	form_basic.hitbox_center_y = 0.85
	form_basic.auto_target_radius = 2.94
	form_basic.lifesteal_ratio = 0.30
	form_basic.vfx_id = "swole_punch"

	var form_q := _ability("skill_q", "不可用", 0.0, 0.0, 0.0, 0.0)
	form_q.disabled = true
	form_q.spawns_attack = false

	var form_w := _ability("skill_w", "肌肉突进", 0.04, 0.20, 0.08, 2.0)
	form_w.damage = 0.0
	form_w.spawns_attack = true
	form_w.requires_aim_confirmation = false
	form_w.face_move_direction_on_cast = true
	form_w.dash_distance = 1.0
	form_w.knockback = 3.2
	form_w.hitbox_size = Vector3(0.95, 1.35, 1.0)
	form_w.hitbox_distance = 0.48
	form_w.hitbox_center_y = 0.78
	form_w.vfx_id = "swole_dash"
	form_w.targeting_preview = "dash"
	form_w.targeting_preview_range = form_w.dash_distance
	form_w.targeting_preview_width = form_w.hitbox_size.x

	var form_e := _ability("skill_e", "震地", 0.28, 0.10, 0.28, 4.0)
	form_e.damage = 10.0
	form_e.knockback = 0.0
	form_e.hitbox_shape = "circle"
	form_e.hitbox_radius = 2.65
	form_e.hitbox_center_y = 0.55
	form_e.apply_slow_ratio = 0.8
	form_e.apply_slow_duration = 1.5
	form_e.requires_aim_confirmation = false
	form_e.lifesteal_ratio = 0.30
	form_e.vfx_id = "swole_slam"

	hero.abilities = [basic, q, w, e, r]
	hero.transformed_abilities = [form_basic, form_q, form_w, form_e]
	return hero


static func _ability(id: String, label: String, startup: float, active: float, recovery: float, cooldown: float) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = id
	ability.display_name = label
	ability.startup = startup
	ability.active = active
	ability.recovery = recovery
	ability.cooldown = cooldown
	ability.color = Color("d6a96a")
	return ability


static func _configure_layers(hero: HeroDefinition) -> void:
	var sword := HeroVisualLayerDefinition.new()
	sword.layer_id = "shield_dog_sword"
	sword.texture = load("res://assets/heroes/sword_shield_dog/sprites/sword_shield_dog_sword_v1.png")
	sword.pixel_size = 0.00062
	sword.offset = Vector2(0.38, 1.04)
	# Move the texture center away from the node so the node becomes the handle pivot.
	sword.texture_offset = Vector2(550.0, 0.0)
	sword.base_rotation = 1.50
	sword.render_priority = 5
	hero.visual_layers.append(sword)

	var shield := HeroVisualLayerDefinition.new()
	shield.layer_id = "shield_dog_shield"
	shield.texture = load("res://assets/heroes/sword_shield_dog/sprites/sword_shield_dog_shield_v1.png")
	shield.pixel_size = 0.00058
	shield.offset = Vector2(-0.35, 0.82)
	shield.base_rotation = 0.0
	shield.render_priority = 3
	hero.visual_layers.append(shield)


static func _configure_pose_clips(hero: HeroDefinition) -> void:
	var walk = PoseClipScript.new()
	walk.duration = 0.56
	walk.loop = true
	walk.add_key(0.00, Vector2(0.00, 0.00), Vector2(1.00, 1.00), 0.00)
	walk.add_key(0.14, Vector2(0.035, 0.080), Vector2(0.97, 1.05), 0.065)
	walk.add_key(0.28, Vector2(0.00, 0.00), Vector2(1.03, 0.97), 0.00)
	walk.add_key(0.42, Vector2(-0.035, 0.080), Vector2(0.97, 1.05), -0.065)
	walk.add_key(0.56, Vector2(0.00, 0.00), Vector2(1.00, 1.00), 0.00)
	hero.sprite_pose_clips["transformed_walk"] = walk

	var basic = PoseClipScript.new()
	basic.duration = 0.42
	basic.add_key(0.00, Vector2.ZERO, Vector2.ONE, 0.00)
	basic.add_key(0.08, Vector2(-0.10, 0.025), Vector2(0.91, 1.08), -0.07)
	basic.add_key(0.13, Vector2(-0.12, 0.035), Vector2(0.89, 1.10), -0.09)
	basic.add_key(0.19, Vector2(0.34, -0.020), Vector2(1.32, 0.82), 0.15)
	basic.add_key(0.25, Vector2(0.26, -0.01), Vector2(1.18, 0.90), 0.09)
	basic.add_key(0.42, Vector2.ZERO, Vector2.ONE, 0.00)
	hero.sprite_pose_clips["transformed_basic"] = basic

	var slam = PoseClipScript.new()
	slam.duration = 0.66
	slam.add_key(0.00, Vector2.ZERO, Vector2.ONE, 0.00)
	slam.add_key(0.20, Vector2(0.00, 0.14), Vector2(0.94, 1.08), -0.035)
	slam.add_key(0.28, Vector2(0.00, 0.27), Vector2(0.89, 1.14), 0.00)
	slam.add_key(0.33, Vector2(0.00, -0.13), Vector2(1.30, 0.70), 0.055)
	slam.add_key(0.44, Vector2(0.00, -0.09), Vector2(1.22, 0.78), 0.035)
	slam.add_key(0.66, Vector2.ZERO, Vector2.ONE, 0.00)
	hero.sprite_pose_clips["transformed_slam"] = slam
