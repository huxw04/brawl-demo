class_name Nailoong
extends RefCounted


static func create() -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.hero_id = "nailoong"
	hero.display_name = "奶龙"
	hero.theme_color = Color("ffd94a")
	hero.max_hp = 180.0
	hero.move_speed = 3.25
	hero.max_energy = 0.0
	hero.status_bar_id = ""
	hero.status_bar_label = ""
	hero.body_radius = 0.43
	hero.body_height = 1.48
	hero.sprite_texture = preload("res://assets/heroes/nailoong/sprites/nailoong_idle_v1.png")
	hero.sprite_pixel_size = 0.00118
	hero.sprite_y = 0.76
	hero.sprite_faces_right = true

	var basic := _ability("basic", "摆尾", 0.12, 0.12, 0.24, 0.52)
	basic.damage = 10.0
	basic.hitbox_shape = "arc"
	basic.hitbox_radius = 2.20
	basic.arc_degrees = 220.0
	basic.hitbox_center_y = 0.65
	basic.auto_target_radius = 2.35
	basic.vfx_id = "nailoong_tail_sweep"
	basic.color = Color("ffe36b")

	var roll := _ability("skill_q", "蜷身滚动", 0.06, 6.0, 0.0, 5.0)
	roll.damage = 0.0
	roll.spawns_attack = false
	roll.requires_aim_confirmation = false
	roll.cancelable_by_ability = true
	roll.cooldown_on_finish = true
	roll.damage_taken_multiplier_during_cast = 0.80
	roll.uninterruptible_by_damage = true
	roll.vfx_id = "nailoong_roll"
	roll.color = Color("ffe675")

	var fire := _ability("skill_w", "持续喷火", 0.10, 5.0, 0.08, 8.0)
	fire.damage = 1.0
	fire.spawns_attack = false
	fire.requires_aim_confirmation = false
	fire.hold_to_channel = true
	fire.minimum_hold_duration = 0.0
	fire.maximum_hold_duration = 5.0
	fire.move_speed_multiplier_during_cast = 0.50
	fire.face_movement_during_cast = true
	fire.projectile_speed = 8.0
	fire.projectile_deceleration = 10.0
	fire.projectile_lifetime = 0.58
	fire.projectile_radius = 0.14
	fire.projectile_height = 0.76
	fire.vfx_id = "nailoong_fire_breath"
	fire.color = Color("ff7a24")

	var leap := _ability("skill_e", "蹦跳震地", 0.08, 0.52, 0.12, 5.0)
	leap.damage = 10.0
	leap.spawns_attack = false
	leap.hitbox_shape = "circle"
	leap.hitbox_radius = 1.50
	leap.hitbox_center_y = 0.62
	leap.apply_slow_ratio = 0.80
	leap.apply_slow_duration = 1.5
	leap.active_duration_override = 0.12
	leap.vfx_id = "nailoong_leap"
	leap.color = Color("ffd657")

	var laugh := _ability("ultimate", "大笑回血", 1.0, 0.02, 0.0, 30.0)
	laugh.damage = 0.0
	laugh.spawns_attack = false
	laugh.requires_aim_confirmation = false
	laugh.locks_movement = true
	laugh.vfx_id = "nailoong_laugh"
	laugh.color = Color("8eea72")

	hero.abilities = [basic, roll, fire, leap, laugh]
	return hero


static func _ability(id: String, label: String, startup: float, active: float, recovery: float, cooldown: float) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = id
	ability.display_name = label
	ability.startup = startup
	ability.active = active
	ability.recovery = recovery
	ability.cooldown = cooldown
	ability.energy_on_hit = 0.0
	return ability
