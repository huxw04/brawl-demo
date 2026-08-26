class_name BearGryllsJungler
extends RefCounted


static func create() -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.hero_id = "bear_grylls_jungler"
	hero.display_name = "贝爷"
	hero.theme_color = Color("6da86b")
	hero.max_hp = 145.0
	hero.move_speed = 3.65
	hero.max_energy = 0.0
	hero.status_bar_id = ""
	hero.status_bar_label = ""
	hero.body_radius = 0.34
	hero.body_height = 1.74
	hero.jump_speed = 6.7
	hero.sprite_texture = preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_idle_v1.png")
	hero.sprite_pixel_size = 0.00110
	hero.sprite_y = 0.84
	hero.sprite_faces_right = true
	hero.movement_sprite_textures = [
		preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_walk_near_v1.png"),
		hero.sprite_texture,
		preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_walk_far_v1.png"),
		hero.sprite_texture,
	]
	# The standing frame is only a brief passing pose, not a visible pause.
	hero.movement_sprite_frame_durations = PackedFloat32Array([0.15, 0.055, 0.15, 0.055])
	hero.action_sprite_textures = {
		"bear_throw_knife": preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_basic_ranged_v1.png"),
		"bear_melee_knife": preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_basic_melee_v1.png"),
		"bear_poison_mark": preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_skill_w_v1.png"),
		"bear_grapple": preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_skill_e_v1.png"),
		"bear_ambush": preload("res://assets/heroes/bear_grylls/sprites/bear_grylls_ultimate_v1.png"),
	}

	var ranged_basic := AbilityDefinition.new()
	ranged_basic.ability_id = "basic"
	ranged_basic.display_name = "投掷小刀"
	ranged_basic.startup = 0.12
	ranged_basic.active = 0.05
	ranged_basic.recovery = 0.23
	ranged_basic.cooldown = 0.50
	ranged_basic.damage = 11.0
	ranged_basic.projectile_speed = 10.0
	ranged_basic.projectile_lifetime = 0.30
	ranged_basic.projectile_radius = 0.13
	ranged_basic.projectile_height = 1.02
	ranged_basic.auto_target_radius = 3.0
	ranged_basic.vfx_id = "bear_throw_knife"
	ranged_basic.color = Color("dce8df")

	var melee_basic := AbilityDefinition.new()
	melee_basic.ability_id = "basic"
	melee_basic.display_name = "近身挥刀"
	melee_basic.startup = 0.10
	melee_basic.active = 0.09
	melee_basic.recovery = 0.21
	melee_basic.cooldown = 0.50
	melee_basic.damage = 13.0
	melee_basic.hitbox_shape = "arc"
	melee_basic.hitbox_radius = 1.0
	melee_basic.arc_degrees = 145.0
	melee_basic.hitbox_size = Vector3(1.0, 1.35, 1.0)
	melee_basic.hitbox_center_y = 0.72
	melee_basic.auto_target_radius = 3.0
	melee_basic.vfx_id = "bear_melee_knife"
	melee_basic.color = Color("e9f1e7")
	hero.ability_variants["basic_melee"] = melee_basic

	var stealth := AbilityDefinition.new()
	stealth.ability_id = "skill_q"
	stealth.display_name = "荒野潜行"
	stealth.startup = 0.08
	stealth.active = 0.02
	stealth.recovery = 0.10
	stealth.cooldown = 8.0
	stealth.damage = 0.0
	stealth.spawns_attack = false
	stealth.requires_aim_confirmation = false
	stealth.breaks_stealth = false
	stealth.vfx_id = "bear_stealth"
	stealth.color = Color("62d19a")

	var poison := AbilityDefinition.new()
	poison.ability_id = "skill_w"
	poison.display_name = "毒刀标记"
	poison.startup = 0.18
	poison.active = 0.12
	poison.recovery = 0.28
	poison.cooldown = 8.0
	poison.damage = 0.0
	poison.hitbox_shape = "circle"
	poison.hitbox_radius = 1.45
	poison.hitbox_size = Vector3(2.9, 1.65, 2.9)
	poison.hitbox_center_y = 0.80
	poison.apply_stun_duration = 1.0
	poison.target_delayed_damage_delay = 2.0
	poison.target_delayed_missing_hp_ratio = 0.15
	poison.requires_aim_confirmation = false
	poison.vfx_id = "bear_poison_mark"
	poison.color = Color("75dd68")

	var grapple := AbilityDefinition.new()
	grapple.ability_id = "skill_e"
	grapple.display_name = "求生钩爪"
	grapple.startup = 0.12
	grapple.active = 0.42
	grapple.recovery = 0.16
	grapple.cooldown = 3.0
	grapple.damage = 6.0
	grapple.projectile_speed = 12.5
	grapple.projectile_lifetime = 0.40
	grapple.projectile_radius = 0.16
	grapple.projectile_height = 0.96
	grapple.apply_stun_duration = 0.5
	grapple.locks_movement = true
	# Throwing the hook is utility, not an attack. Stealth is removed only once
	# the hook actually connects and starts pulling Bear.
	grapple.breaks_stealth = false
	grapple.vfx_id = "bear_grapple"
	grapple.color = Color("bcc9bf")
	grapple.targeting_preview = "line"
	grapple.targeting_preview_range = 5.0
	grapple.targeting_preview_width = grapple.projectile_radius * 2.0

	var ambush := AbilityDefinition.new()
	ambush.ability_id = "ultimate"
	ambush.display_name = "背后奇袭"
	ambush.startup = 0.16
	ambush.active = 0.03
	ambush.recovery = 0.32
	ambush.cooldown = 12.0
	ambush.damage = 20.0
	ambush.spawns_attack = false
	ambush.target_required_range = 5.0
	ambush.vfx_id = "bear_ambush"
	ambush.color = Color("e8f3e8")
	ambush.targeting_preview = "unit"
	ambush.targeting_preview_range = ambush.target_required_range

	hero.abilities = [ranged_basic, stealth, poison, grapple, ambush]
	return hero
