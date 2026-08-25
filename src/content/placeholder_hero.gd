class_name PlaceholderHero
extends RefCounted


static func create() -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.hero_id = "placeholder_vanguard"
	hero.display_name = "灰盒先锋"
	hero.theme_color = Color("55c8d8")
	hero.max_hp = 160.0
	hero.move_speed = 3.8
	hero.jump_cost = 0.0
	hero.roll_cost = hero.max_stamina / 3.0
	hero.body_radius = 0.34
	hero.body_height = 1.72
	hero.jump_speed = 6.7
	hero.sprite_texture = preload("res://assets/placeholder_hero.svg")

	var basic := AbilityDefinition.new()
	basic.ability_id = "basic"
	basic.display_name = "横扫"
	basic.startup = 0.10
	basic.active = 0.11
	basic.recovery = 0.20
	basic.cooldown = 0.34
	basic.damage = 13.0
	basic.knockback = 0.0
	basic.hitbox_size = Vector3(1.45, 1.15, 0.92)
	basic.hitbox_distance = 0.72
	basic.hitbox_center_y = 0.67
	basic.energy_on_hit = 9.0
	basic.color = Color("ffe17c")

	var dash := AbilityDefinition.new()
	dash.ability_id = "skill_q"
	dash.display_name = "破阵突进"
	dash.startup = 0.16
	dash.active = 0.15
	dash.recovery = 0.32
	dash.cooldown = 3.2
	dash.stamina_cost = 18.0
	dash.damage = 24.0
	dash.knockback = 0.0
	dash.hitbox_size = Vector3(1.25, 1.25, 1.2)
	dash.hitbox_distance = 0.88
	dash.hitbox_center_y = 0.7
	dash.movement_impulse = 4.8
	dash.energy_on_hit = 14.0
	dash.color = Color("ff9c55")

	var bolt := AbilityDefinition.new()
	bolt.ability_id = "skill_w"
	bolt.display_name = "回响弹"
	bolt.startup = 0.14
	bolt.active = 0.04
	bolt.recovery = 0.16
	bolt.cooldown = 4.0
	bolt.damage = 18.0
	bolt.knockback = 0.0
	bolt.projectile_speed = 8.2
	bolt.projectile_lifetime = 1.7
	bolt.projectile_radius = 0.2
	bolt.projectile_height = 0.95
	bolt.energy_on_hit = 12.0
	bolt.color = Color("7fe6ff")

	var uppercut := AbilityDefinition.new()
	uppercut.ability_id = "skill_e"
	uppercut.display_name = "升流斩"
	uppercut.startup = 0.2
	uppercut.active = 0.13
	uppercut.recovery = 0.34
	uppercut.cooldown = 4.8
	uppercut.damage = 21.0
	uppercut.knockback = 0.0
	uppercut.hitbox_size = Vector3(1.2, 2.2, 1.0)
	uppercut.hitbox_distance = 0.7
	uppercut.hitbox_center_y = 1.15
	uppercut.energy_on_hit = 13.0
	uppercut.color = Color("8ee8bd")

	var ultimate := AbilityDefinition.new()
	ultimate.ability_id = "ultimate"
	ultimate.display_name = "震荡核心"
	ultimate.startup = 0.42
	ultimate.active = 0.22
	ultimate.recovery = 0.48
	ultimate.cooldown = 7.0
	ultimate.energy_cost = 60.0
	ultimate.damage = 42.0
	ultimate.knockback = 0.0
	ultimate.hitbox_size = Vector3(3.7, 2.25, 3.2)
	ultimate.hitbox_distance = 0.55
	ultimate.hitbox_center_y = 1.05
	ultimate.color = Color("e582ff")

	hero.abilities = [basic, dash, bolt, uppercut, ultimate]
	return hero
