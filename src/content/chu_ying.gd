class_name ChuYing
extends RefCounted


static func create() -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.hero_id = "chu_ying"
	hero.display_name = "褚赢"
	hero.theme_color = Color("e8edf4")
	hero.max_hp = 125.0
	hero.move_speed = 3.15
	hero.max_energy = 3.0
	hero.starts_with_full_energy = true
	hero.status_bar_id = "go_stones"
	hero.status_bar_label = "棋子"
	hero.status_bar_color = Color("dce4ef")
	hero.body_radius = 0.34
	hero.body_height = 1.62
	hero.sprite_texture = preload("res://assets/heroes/chu_ying/sprites/chu_ying_idle_v1.png")
	hero.sprite_pixel_size = 0.00105
	hero.sprite_y = 0.83
	hero.sprite_faces_right = true

	var basic := _ability("basic", "飞棋", 0.10, 0.04, 0.22, 0.48)
	basic.damage = 2.0
	basic.projectile_speed = 8.5
	basic.projectile_lifetime = 0.82
	basic.projectile_radius = 0.12
	basic.projectile_height = 0.86
	basic.projectile_homing = true
	basic.auto_target_radius = 5.0
	basic.target_required_range = 5.0
	basic.vfx_id = "chu_ying_homing_stone"
	basic.color = Color("f4f5f7")

	var q := _ability("skill_q", "天元落子", 0.08, 0.05, 0.12, 0.5)
	q.damage = 5.0
	q.spawns_attack = false
	q.target_required_range = 5.0
	q.hitbox_shape = "circle"
	q.hitbox_radius = 0.30
	q.active_duration_override = 0.10
	q.vfx_id = "chu_ying_falling_stone"
	q.color = Color("f1f3f6")

	var w := _ability("skill_w", "小棋盘", 0.18, 0.05, 0.22, 8.0)
	w.damage = 10.0
	w.spawns_attack = false
	w.target_required_range = 5.0
	w.hitbox_shape = "circle"
	w.hitbox_radius = 0.50
	w.knockup_speed = 5.0
	w.knockup_control_duration = 0.45
	w.vfx_id = "chu_ying_board"
	w.color = Color("d9b36b")

	var e := _ability("skill_e", "棋魂传送", 1.0, 0.02, 0.10, 10.0)
	e.damage = 0.0
	e.spawns_attack = false
	e.target_required_range = 10.0
	e.locks_movement = true
	e.self_control_immune_duration = 1.0
	e.vfx_id = "chu_ying_teleport"
	e.color = Color("d8ecff")

	var r := _ability("ultimate", "棋界禁锢", 0.5, 0.05, 0.20, 30.0)
	r.damage = 0.0
	r.spawns_attack = false
	r.target_required_range = 5.0
	r.locks_movement = true
	r.knockup_speed = 4.2
	r.knockup_control_duration = 0.5
	r.vfx_id = "chu_ying_barrier"
	r.color = Color("e8f2ff")

	hero.abilities = [basic, q, w, e, r]
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
