class_name CheemsSamurai
extends RefCounted


static func create() -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.hero_id = "cheems_samurai"
	hero.display_name = "cheems"
	hero.theme_color = Color("d9a552")
	hero.max_hp = 140.0
	hero.move_speed = 3.65
	hero.max_energy = 100.0
	hero.status_bar_label = "剑意"
	hero.status_bar_color = Color("e4b84d")
	hero.body_radius = 0.39
	hero.body_height = 1.58
	hero.sprite_texture = load("res://assets/heroes/cheems/sprites/cheems_body_v1.png")
	hero.sprite_pixel_size = 0.00110
	hero.sprite_y = 0.84
	hero.sprite_faces_right = false
	_configure_optional_layers(hero)

	var basic := AbilityDefinition.new()
	basic.ability_id = "basic"
	basic.display_name = "居合"
	basic.startup = 0.12
	basic.active = 0.10
	basic.recovery = 0.22
	basic.cooldown = 0.48
	basic.damage = 12.0
	basic.knockback = 0.0
	basic.hitbox_shape = "arc"
	basic.hitbox_radius = 2.20
	basic.arc_degrees = 180.0
	basic.hitbox_center_y = 0.7
	basic.auto_target_radius = 2.35
	basic.energy_on_hit = 5.0
	basic.vfx_id = "katana_sweep"
	basic.color = Color("f7e3a1")

	var q := AbilityDefinition.new()
	q.ability_id = "skill_q"
	q.display_name = "断流"
	q.startup = 0.22
	q.active = 0.04
	q.recovery = 0.28
	q.cooldown = 6.0
	q.damage = 22.0
	q.knockback = 0.8
	# One grid cell is one world unit (100 yards); the wave travels exactly six cells.
	q.projectile_speed = 5.2
	q.projectile_lifetime = 6.0 / q.projectile_speed
	q.projectile_radius = 0.33
	q.projectile_height = 0.52
	q.projectile_destroyer = true
	q.projectile_pierces_actors = true
	q.energy_on_hit = 0.0
	q.vfx_id = "sword_wave"
	q.color = Color("b9efff")
	q.targeting_preview = "line"
	q.targeting_preview_range = 6.0
	q.targeting_preview_width = q.projectile_radius * 2.0

	var w := AbilityDefinition.new()
	w.ability_id = "skill_w"
	w.display_name = "连斩"
	w.startup = 0.16
	w.active = 2.4
	w.recovery = 0.18
	w.cooldown = 5.0
	w.damage = 4.0
	w.knockback = 0.0
	w.hitbox_size = Vector3(1.65, 1.25, 2.25)
	w.hitbox_distance = 1.05
	w.hitbox_center_y = 0.67
	w.hit_interval = 0.3
	w.max_hits_per_target = 8
	w.energy_on_hit = 4.0
	w.healing_on_hit = 5.0
	w.cancelable_by_movement = true
	w.cancelable_by_ability = true
	w.locks_movement = true
	w.vfx_id = "multi_slash"
	w.color = Color("ffd58a")
	w.targeting_preview = "box"

	var e := AbilityDefinition.new()
	e.ability_id = "skill_e"
	e.display_name = "穿云"
	e.startup = 0.06
	e.active = 0.16
	e.recovery = 0.12
	e.cooldown = 2.0
	e.damage = 10.0
	e.knockback = 0.0
	e.hitbox_size = Vector3(0.95, 1.25, 3.2)
	# The actor first reaches the endpoint; the long box is centered behind it to cover the traversed path.
	e.hitbox_distance = 1.55
	e.hitbox_center_y = 0.68
	e.dash_distance = 3.1
	e.endpoint_phase_dash = true
	e.refresh_cooldown_on_hit = true
	e.energy_on_hit = 8.0
	e.vfx_id = "dash_slash"
	e.color = Color("8de7ff")
	e.targeting_preview = "dash"
	e.targeting_preview_range = e.dash_distance
	e.targeting_preview_width = e.hitbox_size.x

	var r := AbilityDefinition.new()
	r.ability_id = "ultimate"
	r.display_name = "次元斩"
	r.startup = 0.5
	r.active = 2.0
	r.recovery = 0.24
	r.cooldown = 10.0
	r.energy_cost = 100.0
	r.damage = 9.0
	r.knockback = 0.0
	r.hitbox_shape = "circle"
	r.hitbox_radius = 2.0
	r.hitbox_center_y = 0.75
	r.hit_interval = 0.5
	r.max_hits_per_target = 4
	r.energy_on_hit = 4.0
	r.requires_aim_confirmation = false
	r.startup_slow_ratio = 0.1
	r.startup_slow_duration = 0.5
	r.apply_root_duration = 2.0
	r.self_control_immune_duration = 0.5
	r.self_untargetable_duration = 2.0
	r.execute_missing_hp_ratio = 0.22
	r.vfx_id = "dimensional_slash"
	r.color = Color("d8c5ff")

	hero.abilities = [basic, q, w, e, r]
	return hero


static func _configure_optional_layers(hero: HeroDefinition) -> void:
	var body_path := "res://assets/heroes/cheems/sprites/cheems_body_v1.png"
	if ResourceLoader.exists(body_path):
		hero.sprite_texture = load(body_path)
	var layer_specs := [
		["hat", "res://assets/heroes/cheems/sprites/cheems_hat_v1.png", Vector2(0.10, 1.70), Vector2.ZERO, 0.000816, 0.0, 1, true, true, PackedStringArray(), PackedStringArray()],
		["scabbard_back", "res://assets/heroes/cheems/sprites/cheems_scabbard_v1.png", Vector2(-0.18, 0.94), Vector2.ZERO, 0.00142, -1.50, -1, true, false, PackedStringArray(), PackedStringArray()],
		["katana_back", "res://assets/heroes/cheems/sprites/cheems_katana_v1.png", Vector2(-0.18, 0.94), Vector2.ZERO, 0.00134, -1.50, -2, true, false, PackedStringArray(), PackedStringArray()],
		["katana_action", "res://assets/heroes/cheems/sprites/cheems_katana_v1.png", Vector2(0.13, 0.79), Vector2(-390.0, 0.0), 0.00118, 0.0, 2, false, false, PackedStringArray(["basic", "skill_q", "skill_w", "skill_e", "ultimate"]), PackedStringArray()],
	]
	for spec in layer_specs:
		if not ResourceLoader.exists(spec[1]):
			continue
		var layer := HeroVisualLayerDefinition.new()
		layer.layer_id = spec[0]
		layer.texture = load(spec[1])
		layer.texture_offset = spec[3]
		layer.pixel_size = spec[4]
		layer.offset = spec[2]
		layer.base_rotation = spec[5]
		layer.render_priority = spec[6]
		layer.visible_by_default = spec[7]
		layer.remove_light_neutral_background = spec[8]
		layer.show_during_actions = spec[9]
		layer.hide_during_actions = spec[10]
		hero.visual_layers.append(layer)
