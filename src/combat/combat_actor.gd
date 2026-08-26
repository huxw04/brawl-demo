class_name CombatActor
extends CharacterBody3D

const NAILOONG_ROLL_TURN_SPEED := TAU

signal resource_changed(actor: CombatActor)
signal action_started(actor: CombatActor, action_id: String)
signal action_finished(actor: CombatActor, action_id: String)
signal damaged(actor: CombatActor, amount: float)
signal defeated(actor: CombatActor)

const AttackHitboxScript = preload("res://src/combat/attack_hitbox.gd")
const ProjectileScript = preload("res://src/combat/combat_projectile.gd")
const DelayedGroundAttackScript = preload("res://src/combat/delayed_ground_attack.gd")
const ChuYingStoneScript = preload("res://src/combat/chu_ying_stone.gd")
const ChuYingBarrierScript = preload("res://src/combat/chu_ying_barrier.gd")
const PLACEHOLDER_TEXTURE = preload("res://assets/placeholder_hero.svg")
const CHEEMS_MAGIC_CIRCLE = preload("res://assets/heroes/cheems/vfx/cheems_magic_circle_v1.png")
const ACTION_SWORD_BODY_INSET := 0.30

static var debug_shapes := false
static var next_attack_id := 1

enum Relation { SELF, ALLY, ENEMY }

var definition: HeroDefinition
var battle_id := 0
var team := 0
var relation := Relation.ENEMY
var actor_name := "Fighter"
var facing := Vector3.RIGHT
var move_intent := Vector2.ZERO
var hp := 1.0
var stamina := 100.0
var energy := 0.0
var cooldowns: Dictionary = {}
var ignore_ability_requirements := false

var current_ability: AbilityDefinition
var ability_phase := "idle"
var phase_remaining := 0.0
var roll_remaining := 0.0
var roll_direction := Vector3.RIGHT
var invulnerable_remaining := 0.0
var stamina_regen_block := 0.0
var hurt_remaining := 0.0
var knockback_velocity := Vector3.ZERO
var flash_remaining := 0.0
var dash_remaining := 0.0
var dash_duration := 0.0
var dash_start := Vector3.ZERO
var dash_end := Vector3.ZERO
var dash_phasing := false
var is_defeated := false
var basic_combo_step := 0
var weapon_drawn := false
var sheathe_remaining := 0.0
var current_attack_damage_multiplier := 1.0
var action_elapsed := 0.0
var w_slash_visual_remaining := 0.0
var visual_rng := RandomNumberGenerator.new()
var active_magic_circle: Node3D
var magic_circle_lifetime_tween: Tween
var dimensional_visual_offset := Vector3.ZERO
var dimensional_visual_from := Vector3.ZERO
var dimensional_visual_to := Vector3.ZERO
var dimensional_visual_segment_remaining := 0.0
var dimensional_visual_segment_duration := 0.0
var death_visual_elapsed := 0.0
var death_fall_side := 1.0
var death_sword_angle := -PI * 0.5
var death_body_start_position := Vector3.ZERO
var death_body_start_scale := Vector3.ONE
var death_layer_start_positions: Dictionary = {}
var death_layer_start_angles: Dictionary = {}
var held_release_requested := false
var transformed_remaining := 0.0
var transformed := false
var base_sprite_texture: Texture2D
var base_sprite_pixel_size := 0.0
var pending_statuses: Array[Dictionary] = []
var pending_damage_events: Array[Dictionary] = []
var pending_ability_target := Vector3.ZERO
var bear_ultimate_target: CombatActor
var bear_grapple_pull_remaining := 0.0
var nailoong_roll_direction := Vector3.RIGHT
var nailoong_roll_dust_remaining := 0.0
var nailoong_fire_emit_remaining := 0.0
var nailoong_fire_emit_index := 0
var nailoong_leap_remaining := 0.0
var nailoong_leap_duration := 0.0
var nailoong_leap_start := Vector3.ZERO
var nailoong_leap_end := Vector3.ZERO
var nailoong_leap_ability: AbilityDefinition
var nailoong_leap_attack_id := 0
var nailoong_regen_tick_remaining := 0.0
var nailoong_regen_ticks_remaining := 0
var chu_ying_q_charges := 0
var chu_ying_q_recharge_remaining := 0.0
var visual_motion_time := 0.0
var movement_animation_time := 0.0
var was_visually_moving := false

var sprite: Sprite3D
var shadow_mesh: MeshInstance3D
var hurt_debug_mesh: MeshInstance3D
var push_debug_mesh: MeshInstance3D
var name_label: Label3D
var hp_label: Label3D
var energy_label: Label3D
var status_visual: MeshInstance3D
var visual_layer_sprites: Dictionary = {}
var ground_marker: Node3D
var status_controller: StatusController

var height: float:
	get:
		return maxf(0.0, global_position.y)


func setup(p_definition: HeroDefinition, p_team: int, p_name := "", p_relation := Relation.ENEMY) -> void:
	definition = p_definition
	team = p_team
	relation = p_relation
	actor_name = p_name if not p_name.is_empty() else definition.display_name
	hp = definition.max_hp
	stamina = definition.max_stamina
	energy = definition.max_energy if definition.starts_with_full_energy else 0.0
	if definition.hero_id == "chu_ying":
		chu_ying_q_charges = 3
		chu_ying_q_recharge_remaining = 0.0
	base_sprite_texture = definition.sprite_texture
	base_sprite_pixel_size = definition.sprite_pixel_size
	visual_rng.randomize()
	collision_layer = 4
	collision_mask = 5 # World + other actors.
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.18
	floor_max_angle = deg_to_rad(48.0)
	add_to_group("combat_actors")
	add_to_group("debug_visuals")
	_create_collision_nodes()
	_create_visual_nodes()
	status_controller = StatusController.new()
	status_controller.name = "StatusController"
	status_controller.periodic_damage_requested.connect(_on_periodic_damage)
	add_child(status_controller)
	refresh_debug_visibility()


func _create_collision_nodes() -> void:
	var push_shape := CollisionShape3D.new()
	push_shape.name = "Pushbox"
	var push_capsule := CapsuleShape3D.new()
	push_capsule.radius = definition.body_radius
	push_capsule.height = definition.body_height
	push_shape.shape = push_capsule
	push_shape.position.y = definition.body_height * 0.5
	add_child(push_shape)

	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	hurtbox.set_meta("combat_actor", self)
	var hurt_shape := CollisionShape3D.new()
	var hurt_capsule := CapsuleShape3D.new()
	hurt_capsule.radius = definition.body_radius * 0.86
	hurt_capsule.height = definition.body_height * 0.96
	hurt_shape.shape = hurt_capsule
	hurt_shape.position.y = definition.body_height * 0.5
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)


func _create_visual_nodes() -> void:
	shadow_mesh = MeshInstance3D.new()
	shadow_mesh.name = "GroundShadow"
	shadow_mesh.top_level = true
	var shadow := CylinderMesh.new()
	shadow.top_radius = definition.body_radius * 1.15
	shadow.bottom_radius = definition.body_radius * 1.15
	shadow.height = 0.018
	shadow.radial_segments = 32
	shadow.material = _material(Color(0.01, 0.02, 0.03, 0.38), true, true)
	shadow_mesh.mesh = shadow
	shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow_mesh)

	sprite = Sprite3D.new()
	sprite.name = "CharacterSprite2D"
	sprite.texture = definition.sprite_texture if definition.sprite_texture != null else PLACEHOLDER_TEXTURE
	sprite.pixel_size = definition.sprite_pixel_size
	sprite.position.y = definition.sprite_y
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.modulate = Color.WHITE if team == 1 else Color("ffb1aa")
	add_child(sprite)

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

	name_label = Label3D.new()
	name_label.text = actor_name
	name_label.position.y = definition.body_height + 0.68
	name_label.font_size = 32
	name_label.pixel_size = 0.007
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.modulate = Color("e8f4fb")
	add_child(name_label)
	hp_label = Label3D.new()
	hp_label.position.y = definition.body_height + 0.43
	hp_label.font_size = 30
	hp_label.pixel_size = 0.0065
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label.no_depth_test = true
	hp_label.outline_size = 7
	hp_label.modulate = relation_color()
	add_child(hp_label)
	energy_label = Label3D.new()
	energy_label.position.y = definition.body_height + 0.25
	energy_label.font_size = 25
	energy_label.pixel_size = 0.0058
	energy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	energy_label.no_depth_test = true
	energy_label.outline_size = 6
	energy_label.modulate = definition.status_bar_color
	add_child(energy_label)
	_create_visual_layers()
	status_visual = MeshInstance3D.new()
	var status_ring := TorusMesh.new()
	status_ring.inner_radius = definition.body_radius * 0.92
	status_ring.outer_radius = definition.body_radius * 1.05
	status_ring.rings = 28
	status_ring.ring_segments = 6
	status_visual.mesh = status_ring
	status_visual.position.y = 0.045
	status_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(status_visual)

	_create_ground_marker()

	push_debug_mesh = _capsule_debug_mesh(definition.body_radius, definition.body_height, Color(0.1, 0.45, 1.0, 0.2))
	push_debug_mesh.position.y = definition.body_height * 0.5
	add_child(push_debug_mesh)
	hurt_debug_mesh = _capsule_debug_mesh(definition.body_radius * 0.86, definition.body_height * 0.96, Color(0.1, 1.0, 0.25, 0.24))
	hurt_debug_mesh.position.y = definition.body_height * 0.5
	add_child(hurt_debug_mesh)


func set_move_intent(value: Vector2) -> void:
	move_intent = value.limit_length(1.0)


func set_ability_target(value: Vector3) -> void:
	pending_ability_target = value


func try_jump(_ignore_cost := false) -> bool:
	if is_defeated or _is_control_locked() or not is_on_floor() or roll_remaining > 0.0 or hurt_remaining > 0.0:
		return false
	velocity.y = definition.jump_speed
	action_started.emit(self, "jump")
	return true


func try_roll(ignore_cost := false) -> bool:
	if is_defeated or _is_control_locked() or not is_on_floor() or roll_remaining > 0.0 or current_ability != null or hurt_remaining > 0.0:
		return false
	var roll_cost := definition.max_stamina / 3.0
	var bypass_cost := ignore_cost or ignore_ability_requirements
	if not bypass_cost and stamina < roll_cost:
		return false
	if not bypass_cost:
		spend_stamina(roll_cost)
	roll_direction = _intent_direction() if move_intent.length_squared() > 0.01 else facing
	facing = roll_direction
	roll_remaining = 0.38
	invulnerable_remaining = 0.27
	action_started.emit(self, "roll")
	return true


func try_ability(id: String, ignore_requirements := false) -> bool:
	if current_ability != null and current_ability.cancelable_by_ability:
		_cancel_current_ability()
	if is_defeated or _is_control_locked() or current_ability != null or roll_remaining > 0.0 or hurt_remaining > 0.0:
		return false
	var ability := ability_by_id(id)
	if ability == null or ability.disabled:
		return false
	if definition.hero_id == "bear_grylls_jungler" and id == "basic":
		ability = _bear_basic_for_current_range(ability)
	if definition.hero_id == "bear_grylls_jungler" and id == "ultimate":
		bear_ultimate_target = _bear_find_ultimate_target(ability.target_required_range)
		if bear_ultimate_target == null:
			return false
	if definition.hero_id == "chu_ying" and id == "skill_q" and chu_ying_q_charges <= 0 and not ignore_requirements and not ignore_ability_requirements:
		return false
	var bypass := ignore_requirements or ignore_ability_requirements
	if not bypass:
		if float(cooldowns.get(id, 0.0)) > 0.0 or stamina < ability.stamina_cost or energy < ability.energy_cost:
			return false
		spend_stamina(ability.stamina_cost)
		energy = maxf(0.0, energy - ability.energy_cost)
	if definition.hero_id == "chu_ying" and id == "skill_q" and not bypass:
		chu_ying_q_charges = maxi(0, chu_ying_q_charges - 1)
		energy = float(chu_ying_q_charges)
		if chu_ying_q_recharge_remaining <= 0.0:
			chu_ying_q_recharge_remaining = 5.0
	if id == "basic" and definition.hero_id == "cheems_samurai":
		if weapon_drawn:
			basic_combo_step = (basic_combo_step + 1) % 3
			current_attack_damage_multiplier = 1.0
		else:
			basic_combo_step = 0
			current_attack_damage_multiplier = 1.5
		weapon_drawn = true
		sheathe_remaining = 0.0
	else:
		current_attack_damage_multiplier = 1.0
	current_ability = ability
	held_release_requested = false
	ability_phase = "startup"
	phase_remaining = ability.startup
	action_elapsed = 0.0
	visual_motion_time = 0.0
	movement_animation_time = 0.0
	was_visually_moving = false
	w_slash_visual_remaining = 0.0
	if not ability.hold_to_channel and not ability.cooldown_on_finish and not ability.cooldown_on_form_end:
		cooldowns[id] = ability.cooldown
	_apply_startup_effects(ability)
	action_started.emit(self, id)
	resource_changed.emit(self)
	return true


func ability_by_id(id: String) -> AbilityDefinition:
	if transformed:
		var transformed_ability := definition.transformed_ability_by_id(id)
		if transformed_ability != null:
			return transformed_ability
		if id in ["skill_q", "skill_w", "skill_e", "ultimate"]:
			return null
	return definition.ability_by_id(id)


func release_held_ability(id: String) -> void:
	if current_ability == null or current_ability.ability_id != id or not current_ability.hold_to_channel:
		return
	held_release_requested = true
	_try_finish_held_ability()


func cancel_nailoong_roll_for_command() -> void:
	if current_ability != null and current_ability.vfx_id == "nailoong_roll":
		_cancel_current_ability()


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_update_timers(delta)
	_update_action(delta)
	_update_motion(delta)
	_update_visual(delta)


func _update_timers(delta: float) -> void:
	status_controller.advance(delta)
	_update_pending_statuses(delta)
	_update_pending_damage_events(delta)
	for key in cooldowns.keys():
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	stamina_regen_block = maxf(0.0, stamina_regen_block - delta)
	hurt_remaining = maxf(0.0, hurt_remaining - delta)
	flash_remaining = maxf(0.0, flash_remaining - delta)
	bear_grapple_pull_remaining = maxf(0.0, bear_grapple_pull_remaining - delta)
	_update_nailoong_regeneration(delta)
	_update_chu_ying_charges(delta)
	if transformed:
		transformed_remaining = maxf(0.0, transformed_remaining - delta)
		if transformed_remaining <= 0.0:
			_exit_transformed_form()
	if current_ability == null and sheathe_remaining > 0.0:
		sheathe_remaining = maxf(0.0, sheathe_remaining - delta)
		if sheathe_remaining <= 0.0:
			weapon_drawn = false
			basic_combo_step = 0
	if stamina_regen_block <= 0.0 and stamina < definition.max_stamina and not is_defeated:
		stamina = minf(definition.max_stamina, stamina + definition.stamina_regen * delta)
		resource_changed.emit(self)


func _update_action(delta: float) -> void:
	if roll_remaining > 0.0:
		roll_remaining = maxf(0.0, roll_remaining - delta)
		if roll_remaining <= 0.0:
			action_finished.emit(self, "roll")
	if current_ability == null:
		return
	action_elapsed += delta
	_update_continuous_ability_vfx(delta)
	if ability_phase == "active" and current_ability.hold_to_channel:
		_try_finish_held_ability()
		return
	phase_remaining -= delta
	if phase_remaining > 0.0:
		return
	if ability_phase == "startup":
		ability_phase = "active"
		phase_remaining = current_ability.active
		_activate_ability(current_ability)
	elif ability_phase == "active":
		ability_phase = "recovery"
		phase_remaining = current_ability.recovery
	else:
		var finished_id := current_ability.ability_id
		var finished_ability := current_ability
		if finished_id == "basic":
			sheathe_remaining = current_ability.cooldown * 0.5
		current_ability = null
		ability_phase = "idle"
		phase_remaining = 0.0
		action_finished.emit(self, finished_id)
		if finished_ability.cooldown_on_finish:
			cooldowns[finished_id] = finished_ability.cooldown


func _try_finish_held_ability() -> void:
	if current_ability == null or not current_ability.hold_to_channel:
		return
	var auto_finished := current_ability.maximum_hold_duration > 0.0 and action_elapsed >= current_ability.startup + current_ability.maximum_hold_duration
	if not held_release_requested and not auto_finished:
		return
	if not auto_finished and action_elapsed < current_ability.startup + current_ability.minimum_hold_duration:
		return
	var finished_id := current_ability.ability_id
	var cooldown := current_ability.cooldown
	current_ability = null
	ability_phase = "idle"
	phase_remaining = 0.0
	held_release_requested = false
	cooldowns[finished_id] = cooldown
	action_finished.emit(self, finished_id)
	resource_changed.emit(self)


func _update_continuous_ability_vfx(delta: float) -> void:
	if current_ability == null or ability_phase != "active":
		return
	match current_ability.vfx_id:
		"multi_slash":
			w_slash_visual_remaining -= delta
			while w_slash_visual_remaining <= 0.0:
				_spawn_horizontal_slash(current_ability)
				w_slash_visual_remaining += 0.09
		"nailoong_fire_breath":
			if current_ability.maximum_hold_duration > 0.0 and action_elapsed >= current_ability.startup + current_ability.maximum_hold_duration:
				return
			nailoong_fire_emit_remaining -= delta
			while nailoong_fire_emit_remaining <= 0.0:
				_spawn_nailoong_fireball(current_ability)
				nailoong_fire_emit_remaining += 0.10
		"nailoong_roll":
			nailoong_roll_dust_remaining -= delta
			if nailoong_roll_dust_remaining <= 0.0:
				_spawn_nailoong_roll_dust()
				nailoong_roll_dust_remaining += 0.08


func _activate_ability(ability: AbilityDefinition) -> void:
	var attack_id := next_attack_id
	next_attack_id += 1
	if ability.breaks_stealth and status_controller.has_tag("stealth"):
		status_controller.remove("bear_stealth")
	if ability.vfx_id == "bear_stealth":
		apply_status(CombatStatuses.stealth(15.0), battle_id)
		_spawn_ability_vfx(ability)
		return
	if ability.vfx_id == "bear_ambush":
		_activate_bear_ambush(ability, attack_id)
		return
	if ability.vfx_id == "nailoong_roll":
		nailoong_roll_direction = facing.normalized() if facing.length_squared() > 0.001 else Vector3.RIGHT
		nailoong_roll_dust_remaining = 0.0
		_spawn_ability_vfx(ability)
		return
	if ability.vfx_id == "nailoong_fire_breath":
		nailoong_fire_emit_remaining = 0.0
		nailoong_fire_emit_index = 0
		_spawn_ability_vfx(ability)
		return
	if ability.vfx_id == "nailoong_leap":
		_start_nailoong_leap(ability, attack_id)
		return
	if ability.vfx_id == "nailoong_laugh":
		nailoong_regen_tick_remaining = 0.5
		nailoong_regen_ticks_remaining = 10
		_spawn_ability_vfx(ability)
		return
	if ability.vfx_id == "chu_ying_homing_stone":
		_activate_chu_ying_basic(ability, attack_id)
		return
	if ability.vfx_id == "chu_ying_falling_stone":
		_activate_chu_ying_q(ability, attack_id)
		return
	if ability.vfx_id == "chu_ying_board":
		_activate_chu_ying_board(ability, attack_id)
		return
	if ability.vfx_id == "chu_ying_teleport":
		_activate_chu_ying_teleport(ability)
		return
	if ability.vfx_id == "chu_ying_barrier":
		_activate_chu_ying_barrier(ability, attack_id)
		return
	var has_second_stage := true
	if ability.vfx_id == "dimensional_slash":
		has_second_stage = _has_enemy_in_radius(ability.hitbox_radius)
	if ability.self_untargetable_duration > 0.0 and has_second_stage:
		apply_status(CombatStatuses.untargetable(ability.self_untargetable_duration), battle_id)
	if ability.vfx_id == "dimensional_slash" and not has_second_stage:
		ability_phase = "recovery"
		phase_remaining = 0.08
		_dismiss_magic_circle(0.06)
		return
	if ability.dash_distance > 0.0:
		_perform_dash(ability)
	if ability.movement_impulse > 0.0:
		knockback_velocity += facing * ability.movement_impulse
	if ability.is_projectile():
		var projectile := ProjectileScript.new() as CombatProjectile
		get_parent().add_child(projectile)
		projectile.global_position = global_position + facing * 0.62 + Vector3.UP * ability.projectile_height
		projectile.configure(self, ability, facing, attack_id)
	elif ability.spawns_attack:
		var hitbox := AttackHitboxScript.new() as AttackHitbox
		add_child(hitbox)
		hitbox.configure(self, ability, attack_id)
	if ability.delayed_damage > 0.0 and ability.delayed_delay > 0.0 and ability.delayed_radius > 0.0:
		var delayed := DelayedGroundAttackScript.new() as DelayedGroundAttack
		get_parent().add_child(delayed)
		var delayed_center := global_position + facing * ability.delayed_center_distance
		delayed.configure(self, ability, attack_id, delayed_center)
	_spawn_ability_vfx(ability)
	if ability.vfx_id == "sword_shield_transform":
		_enter_transformed_form()


func _apply_startup_effects(ability: AbilityDefinition) -> void:
	if ability.self_control_immune_duration > 0.0:
		apply_status(CombatStatuses.control_immune(ability.self_control_immune_duration), battle_id)
	if ability.vfx_id == "chu_ying_teleport":
		_spawn_chu_ying_teleport_charge(ability.startup)
	elif ability.vfx_id == "dimensional_slash":
		_spawn_concentration_rings(ability.hitbox_radius, ability.startup, "CheemsUltimateFocus")
	if ability.startup_slow_duration <= 0.0:
		return
	if ability.startup_slow_ratio < 1.0:
		for value in get_tree().get_nodes_in_group("combat_actors"):
			if value is CombatActor:
				var target := value as CombatActor
				if target != self and target.team != team and not target.is_defeated and global_position.distance_squared_to(target.global_position) <= ability.hitbox_radius * ability.hitbox_radius:
					target.apply_status(CombatStatuses.slow(ability.startup_slow_duration, ability.startup_slow_ratio), battle_id)
	if ability.vfx_id == "dimensional_slash":
		_spawn_magic_circle(ability, ability.startup + ability.active)


func _update_motion(delta: float) -> void:
	if nailoong_leap_remaining > 0.0:
		nailoong_leap_remaining = maxf(0.0, nailoong_leap_remaining - delta)
		var leap_progress := 1.0 - nailoong_leap_remaining / maxf(nailoong_leap_duration, 0.001)
		global_position = nailoong_leap_start.lerp(nailoong_leap_end, leap_progress)
		global_position.y += sin(leap_progress * PI) * 1.05
		velocity = Vector3.ZERO
		if nailoong_leap_remaining <= 0.0:
			global_position = nailoong_leap_end
			_finish_nailoong_leap()
		return
	if not is_on_floor():
		velocity.y -= definition.gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	if dash_remaining > 0.0:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		if dash_phasing:
			var progress := 1.0 - dash_remaining / maxf(dash_duration, 0.001)
			global_position = dash_start.lerp(dash_end, ease(progress, -1.8))
			velocity = Vector3.ZERO
			if dash_remaining <= 0.0:
				global_position = dash_end
		else:
			var dash_velocity := facing * global_position.distance_to(dash_end) / maxf(dash_remaining, delta)
			velocity.x = dash_velocity.x
			velocity.z = dash_velocity.z
			move_and_slide()
			for collision_index in range(get_slide_collision_count()):
				var collision := get_slide_collision(collision_index)
				# Floor contact is expected during a grounded dash. Only a mostly
				# horizontal normal represents a wall or another actor blocking it.
				if absf(collision.get_normal().y) < 0.65:
					dash_remaining = 0.0
					break
		if dash_remaining <= 0.0:
			velocity.x = 0.0
			velocity.z = 0.0
		return
	if current_ability != null and current_ability.vfx_id == "nailoong_roll" and ability_phase == "active":
		var desired_roll_direction := _intent_direction()
		if desired_roll_direction.length_squared() > 0.001:
			var turn_angle := nailoong_roll_direction.signed_angle_to(desired_roll_direction, Vector3.UP)
			var turn_step := clampf(turn_angle, -NAILOONG_ROLL_TURN_SPEED * delta, NAILOONG_ROLL_TURN_SPEED * delta)
			nailoong_roll_direction = (Basis(Vector3.UP, turn_step) * nailoong_roll_direction).normalized()
			facing = nailoong_roll_direction
		var roll_speed := definition.move_speed * 1.65
		var motion := nailoong_roll_direction * roll_speed * delta
		var ray_height := definition.body_radius * 1.05
		var ray_start := global_position + Vector3.UP * ray_height
		var ray_query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + motion + nailoong_roll_direction * definition.body_radius, 1)
		ray_query.collide_with_areas = false
		ray_query.collide_with_bodies = true
		var collision := get_world_3d().direct_space_state.intersect_ray(ray_query)
		if not collision.is_empty() and absf(Vector3(collision["normal"]).y) < 0.65:
			var normal := Vector3(collision["normal"])
			var contact := Vector3(collision["position"])
			global_position.x = contact.x - nailoong_roll_direction.x * (definition.body_radius + 0.025)
			global_position.z = contact.z - nailoong_roll_direction.z * (definition.body_radius + 0.025)
			var bounced := nailoong_roll_direction.bounce(normal)
			bounced.y = 0.0
			if bounced.length_squared() > 0.001:
				nailoong_roll_direction = bounced.normalized()
				facing = nailoong_roll_direction
				_spawn_nailoong_bounce_flash(contact)
		else:
			global_position += motion
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if is_defeated or _is_control_locked():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if current_ability != null and current_ability.cancelable_by_movement and move_intent.length_squared() > 0.01:
		if current_ability.hold_to_channel:
			held_release_requested = true
			_try_finish_held_ability()
		else:
			_cancel_current_ability()
	var horizontal := Vector3.ZERO
	if roll_remaining > 0.0:
		horizontal = roll_direction * 7.7
	elif hurt_remaining > 0.0:
		horizontal = knockback_velocity
	elif current_ability != null and current_ability.locks_movement:
		horizontal = knockback_velocity
	elif current_ability != null:
		horizontal = _intent_direction() * definition.move_speed * move_intent.length() * current_ability.move_speed_multiplier_during_cast + knockback_velocity
		if current_ability.face_movement_during_cast and move_intent.length_squared() > 0.01:
			facing = _intent_direction()
	else:
		var form_speed := definition.transformed_move_speed_multiplier if transformed else 1.0
		var movement_speed := definition.move_speed * form_speed * status_controller.multiplier("move_speed")
		horizontal = _intent_direction() * movement_speed * move_intent.length() + knockback_velocity
		if move_intent.length_squared() > 0.01:
			facing = _intent_direction()
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 11.0 * delta)
	move_and_slide()


func _intent_direction() -> Vector3:
	var direction := Vector3(move_intent.x, 0.0, move_intent.y)
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO


func receive_hit(source: CombatActor, ability: AbilityDefinition, direction: Vector3, _attack_id: int, damage_override := -1.0) -> bool:
	if is_defeated or invulnerable_remaining > 0.0 or not is_targetable():
		return false
	if _blocks_attack_from(source):
		_spawn_block_flash()
		return false
	var dealt_damage: float = ability.damage if damage_override < 0.0 else damage_override
	if source != null:
		dealt_damage = source.modify_outgoing_damage(self, ability, dealt_damage)
	if current_ability != null and ability_phase == "active":
		dealt_damage *= current_ability.damage_taken_multiplier_during_cast
	hp = maxf(0.0, hp - dealt_damage)
	energy = minf(definition.max_energy, energy + dealt_damage * 0.38)
	var has_armor := status_controller.has_tag("control_immune")
	if not has_armor:
		knockback_velocity = Vector3(direction.x, 0.0, direction.z).normalized() * ability.knockback
		hurt_remaining = maxf(0.12, ability.knockup_control_duration)
		if ability.knockup_speed > 0.0:
			velocity.y = maxf(velocity.y, ability.knockup_speed)
		dash_remaining = 0.0
	flash_remaining = 0.13
	if not has_armor and not (current_ability != null and current_ability.uninterruptible_by_damage):
		_cancel_current_ability()
	damaged.emit(self, dealt_damage)
	resource_changed.emit(self)
	if hp <= 0.0:
		_mark_defeated()
		if source != null:
			source.on_killed_actor(self, ability)
	return true


func _cancel_current_ability() -> void:
	if current_ability == null:
		return
	var interrupted_id := current_ability.ability_id
	var interrupted_ability := current_ability
	if interrupted_id == "basic":
		sheathe_remaining = current_ability.cooldown * 0.5
	current_ability = null
	ability_phase = "idle"
	phase_remaining = 0.0
	for child in get_children():
		if child is AttackHitbox:
			child.queue_free()
	action_finished.emit(self, interrupted_id)
	if interrupted_ability.hold_to_channel or interrupted_ability.cooldown_on_finish:
		cooldowns[interrupted_id] = interrupted_ability.cooldown


func spend_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(0.0, stamina - amount)
	stamina_regen_block = definition.stamina_regen_delay
	resource_changed.emit(self)


func gain_energy(amount: float) -> void:
	energy = minf(definition.max_energy, energy + amount)
	resource_changed.emit(self)


func reset_runtime(at_position: Vector3) -> void:
	_dismiss_magic_circle(0.0)
	global_position = at_position
	velocity = Vector3.ZERO
	hp = definition.max_hp
	stamina = definition.max_stamina
	energy = definition.max_energy if definition.starts_with_full_energy else 0.0
	cooldowns.clear()
	current_ability = null
	ability_phase = "idle"
	roll_remaining = 0.0
	invulnerable_remaining = 0.0
	stamina_regen_block = 0.0
	hurt_remaining = 0.0
	dash_remaining = 0.0
	dash_duration = 0.0
	dash_phasing = false
	basic_combo_step = 0
	weapon_drawn = false
	sheathe_remaining = 0.0
	current_attack_damage_multiplier = 1.0
	action_elapsed = 0.0
	visual_motion_time = 0.0
	dimensional_visual_offset = Vector3.ZERO
	dimensional_visual_from = Vector3.ZERO
	dimensional_visual_to = Vector3.ZERO
	dimensional_visual_segment_remaining = 0.0
	dimensional_visual_segment_duration = 0.0
	held_release_requested = false
	transformed = false
	transformed_remaining = 0.0
	sprite.texture = base_sprite_texture
	sprite.pixel_size = base_sprite_pixel_size
	death_visual_elapsed = 0.0
	death_layer_start_positions.clear()
	death_layer_start_angles.clear()
	knockback_velocity = Vector3.ZERO
	is_defeated = false
	collision_layer = 4
	sprite.position = Vector3(0.0, definition.sprite_y, sprite.position.z)
	_set_visual_layer_angle(sprite, 0.0)
	sprite.scale = Vector3.ONE
	sprite.visible = true
	name_label.visible = true
	hp_label.visible = true
	energy_label.visible = true
	status_visual.visible = true
	ground_marker.visible = true
	status_controller.clear()
	pending_statuses.clear()
	pending_damage_events.clear()
	pending_ability_target = Vector3.ZERO
	bear_ultimate_target = null
	bear_grapple_pull_remaining = 0.0
	nailoong_roll_direction = Vector3.RIGHT
	nailoong_roll_dust_remaining = 0.0
	nailoong_fire_emit_remaining = 0.0
	nailoong_fire_emit_index = 0
	nailoong_leap_remaining = 0.0
	nailoong_leap_duration = 0.0
	nailoong_leap_ability = null
	nailoong_leap_attack_id = 0
	nailoong_regen_tick_remaining = 0.0
	nailoong_regen_ticks_remaining = 0
	chu_ying_q_charges = 3 if definition.hero_id == "chu_ying" else 0
	chu_ying_q_recharge_remaining = 0.0
	for child in get_children():
		if child is AttackHitbox:
			child.queue_free()
	resource_changed.emit(self)


func cooldown_ratio(id: String) -> float:
	var ability := ability_by_id(id)
	if ability == null:
		ability = definition.ability_by_id(id)
	if ability == null or ability.cooldown <= 0.0:
		return 0.0
	return clampf(float(cooldowns.get(id, 0.0)) / ability.cooldown, 0.0, 1.0)


func status_text() -> String:
	if is_defeated:
		return "DEFEATED"
	if roll_remaining > 0.0:
		return "ROLL / I-FRAME" if invulnerable_remaining > 0.0 else "ROLL"
	if hurt_remaining > 0.0:
		return "HURT"
	if current_ability != null:
		return "%s · %s" % [current_ability.display_name, ability_phase.to_upper()]
	if not is_on_floor():
		return "JUMP %.2f m" % height
	if _is_control_locked():
		return "STUNNED"
	return "IDLE" if move_intent.length_squared() < 0.01 else "MOVE"


func pending_damage_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in pending_damage_events:
		var ability := entry.get("ability") as AbilityDefinition
		result.append({
			"source": int(entry.get("source_id", 0)),
			"ability": "" if ability == null else ability.ability_id,
			"remaining": roundi(float(entry.get("remaining", 0.0)) * 10000.0),
			"ratio": roundi(float(entry.get("ratio", 0.0)) * 10000.0),
		})
	return result


func hero_runtime_snapshot() -> Dictionary:
	if definition == null:
		return {}
	match definition.hero_id:
		"nailoong":
			return {
				"roll_direction": [roundi(nailoong_roll_direction.x * 10000.0), roundi(nailoong_roll_direction.y * 10000.0), roundi(nailoong_roll_direction.z * 10000.0)],
				"fire_index": nailoong_fire_emit_index,
				"fire_timer": roundi(nailoong_fire_emit_remaining * 10000.0),
				"leap_remaining": roundi(nailoong_leap_remaining * 10000.0),
				"leap_end": [roundi(nailoong_leap_end.x * 10000.0), roundi(nailoong_leap_end.y * 10000.0), roundi(nailoong_leap_end.z * 10000.0)],
				"regen_ticks": nailoong_regen_ticks_remaining,
				"regen_timer": roundi(nailoong_regen_tick_remaining * 10000.0),
			}
		"chu_ying":
			return {
				"q_charges": chu_ying_q_charges,
				"q_recharge": roundi(chu_ying_q_recharge_remaining * 10000.0),
			}
	return {}


func refresh_debug_visibility() -> void:
	if hurt_debug_mesh != null:
		hurt_debug_mesh.visible = debug_shapes
	if push_debug_mesh != null:
		push_debug_mesh.visible = debug_shapes


func _update_visual(delta: float) -> void:
	visual_motion_time += delta
	shadow_mesh.global_position = Vector3(global_position.x, 0.018, global_position.z)
	shadow_mesh.scale = Vector3.ONE * clampf(1.0 - height * 0.09, 0.68, 1.0)
	if is_defeated:
		_update_death_visual(delta)
		return
	var facing_left := facing.x < -0.05
	var facing_sign := -1.0 if facing_left else 1.0
	_update_movement_sprite(delta)
	sprite.flip_h = facing_left if definition.sprite_faces_right else not facing_left
	var target_scale := Vector3.ONE
	var nailoong_rolling := current_ability != null and current_ability.vfx_id == "nailoong_roll" and ability_phase == "active"
	if nailoong_rolling:
		target_scale = Vector3(0.84, 0.84, 1.0)
	elif current_ability != null and current_ability.vfx_id == "nailoong_laugh" and ability_phase == "startup":
		var laugh_bounce := sin(action_elapsed * TAU * 5.0)
		target_scale = Vector3(1.0 + laugh_bounce * 0.08, 1.0 - laugh_bounce * 0.08, 1.0)
	elif transformed and current_ability != null and current_ability.vfx_id == "swole_dash" and ability_phase == "active":
		target_scale = Vector3(1.30, 0.88, 1.0)
	elif transformed:
		target_scale = Vector3(1.08, 1.08, 1.0)
	elif roll_remaining > 0.0:
		target_scale = Vector3(1.28, 0.72, 1.0)
	elif ability_phase == "startup" and not (current_ability != null and current_ability.vfx_id == "dimensional_slash"):
		target_scale = Vector3(0.92, 1.08, 1.0)
	elif ability_phase == "active":
		target_scale = Vector3(1.18, 0.9, 1.0)
	var sprite_pose := _current_sprite_pose()
	var pose_scale: Vector2 = sprite_pose["scale"]
	target_scale.x *= pose_scale.x
	target_scale.y *= pose_scale.y
	var dimensional_action := current_ability != null and current_ability.vfx_id == "dimensional_slash"
	if dimensional_action and ability_phase == "active":
		_update_dimensional_visual_motion(delta, current_ability.hitbox_radius)
	else:
		dimensional_visual_offset = dimensional_visual_offset.move_toward(Vector3.ZERO, delta * 8.0)
		dimensional_visual_segment_remaining = 0.0
	var pose_offset: Vector2 = sprite_pose["offset"]
	sprite.position.x = dimensional_visual_offset.x + pose_offset.x * facing_sign
	sprite.position.y = definition.sprite_y + pose_offset.y
	sprite.position.z = dimensional_visual_offset.z
	sprite.scale = sprite.scale.lerp(target_scale, minf(1.0, delta * 15.0))
	var visual_angle := float(sprite_pose["angle"]) * facing_sign
	if nailoong_rolling:
		visual_angle += action_elapsed * 10.5 * facing_sign
	elif current_ability != null and current_ability.vfx_id == "nailoong_tail_sweep":
		# The tail attack reads as a full body spin rather than a small sideways wobble.
		visual_angle += clampf(action_elapsed / maxf(current_ability.total_duration(), 0.01), 0.0, 1.0) * TAU * facing_sign
	_set_visual_layer_angle(sprite, visual_angle)
	var base_color := Color.WHITE if team == 1 else Color("ffb1aa")
	if status_controller.has_visual("slow"):
		base_color = base_color.lerp(Color("74cfff"), 0.28)
	elif status_controller.has_visual("poison"):
		base_color = base_color.lerp(Color("8be35a"), 0.32)
	if status_controller.has_tag("untargetable"):
		base_color.a = 0.34
	var stealthed := status_controller.has_tag("stealth")
	var hidden_from_local_view := stealthed and relation != Relation.SELF
	if stealthed and relation == Relation.SELF:
		base_color.a = minf(base_color.a, 0.20)
	sprite.modulate = Color.WHITE if flash_remaining > 0.0 else base_color
	sprite.visible = not hidden_from_local_view
	shadow_mesh.visible = not hidden_from_local_view
	ground_marker.global_position = Vector3(global_position.x, 0.05, global_position.z)
	ground_marker.rotation.y = atan2(-facing.x, -facing.z)
	ground_marker.visible = not is_defeated and not hidden_from_local_view
	var overhead := status_controller.overhead_text()
	name_label.text = overhead if not overhead.is_empty() else actor_name
	name_label.modulate = Color("ffe29a") if not overhead.is_empty() else Color("e8f4fb")
	var filled := clampi(ceili((hp / definition.max_hp) * 12.0), 0, 12)
	hp_label.text = "▰".repeat(filled) + "▱".repeat(12 - filled)
	var has_status_resource := definition.max_energy > 0.0 and not definition.status_bar_id.is_empty()
	if has_status_resource:
		var energy_filled := clampi(ceili((energy / definition.max_energy) * 12.0), 0, 12)
		energy_label.text = "▰".repeat(energy_filled) + "▱".repeat(12 - energy_filled)
	else:
		energy_label.text = ""
	name_label.visible = not hidden_from_local_view
	hp_label.visible = not hidden_from_local_view
	energy_label.visible = has_status_resource and not hidden_from_local_view
	_update_visual_layers()
	var visual_color := Color(0.3, 0.8, 1.0, 0.0)
	if status_controller.has_visual("slow"):
		visual_color = Color("62cfff")
	elif status_controller.has_visual("poison"):
		visual_color = Color("78d84e")
	elif status_controller.has_tag("control_immune"):
		visual_color = Color("ffd45b")
	status_visual.visible = visual_color.a > 0.0 and not hidden_from_local_view
	if status_visual.visible:
		(status_visual.mesh as TorusMesh).material = _material(Color(visual_color, 0.78), true, true)
		status_visual.rotation.y += delta * 2.4


func _update_movement_sprite(delta: float) -> void:
	if transformed:
		was_visually_moving = false
		return
	if definition.hero_id == "bear_grylls_jungler" and bear_grapple_pull_remaining > 0.0:
		movement_animation_time = 0.0
		was_visually_moving = false
		var pull_texture = definition.action_sprite_textures.get("bear_grapple")
		sprite.texture = pull_texture as Texture2D if pull_texture is Texture2D else base_sprite_texture
		return
	if current_ability != null:
		movement_animation_time = 0.0
		was_visually_moving = false
		# E begins with the same outstretched throwing pose as the ranged basic.
		# The grapple-specific braced pose is selected only after a hit starts pulling.
		var action_key := "bear_throw_knife" if current_ability.vfx_id == "bear_grapple" else current_ability.vfx_id
		var action_texture = definition.action_sprite_textures.get(action_key)
		sprite.texture = action_texture as Texture2D if action_texture is Texture2D else base_sprite_texture
		return
	var moving := (
		current_ability == null
		and roll_remaining <= 0.0
		and move_intent.length_squared() > 0.01
		and is_on_floor()
	)
	if not moving or definition.movement_sprite_textures.is_empty():
		movement_animation_time = 0.0
		was_visually_moving = false
		sprite.texture = base_sprite_texture
		return
	if not was_visually_moving:
		movement_animation_time = 0.0
	else:
		movement_animation_time += delta
	was_visually_moving = true
	var durations := definition.movement_sprite_frame_durations
	var total_duration := 0.0
	for index in range(definition.movement_sprite_textures.size()):
		total_duration += durations[index] if index < durations.size() else 0.12
	if total_duration <= 0.0:
		sprite.texture = definition.movement_sprite_textures[0]
		return
	var local_time := fmod(movement_animation_time, total_duration)
	for index in range(definition.movement_sprite_textures.size()):
		var frame_duration := durations[index] if index < durations.size() else 0.12
		if local_time < frame_duration:
			sprite.texture = definition.movement_sprite_textures[index]
			return
		local_time -= frame_duration
	sprite.texture = definition.movement_sprite_textures.back()


func _current_sprite_pose() -> Dictionary:
	var neutral := {"offset": Vector2.ZERO, "scale": Vector2.ONE, "angle": 0.0}
	if not transformed:
		return neutral
	var clip_id := ""
	var clip_time := 0.0
	if current_ability != null and current_ability.vfx_id == "swole_punch":
		clip_id = "transformed_basic"
		clip_time = action_elapsed
	elif current_ability != null and current_ability.vfx_id == "swole_slam":
		clip_id = "transformed_slam"
		clip_time = action_elapsed
	elif current_ability == null and move_intent.length_squared() > 0.01 and is_on_floor():
		clip_id = "transformed_walk"
		clip_time = visual_motion_time
	var clip = definition.sprite_pose_clips.get(clip_id)
	return clip.call("sample", clip_time) if clip != null and clip.has_method("sample") else neutral


func is_targetable() -> bool:
	return not status_controller.has_tag("untargetable")


func is_visible_to(observer_team: int) -> bool:
	return not status_controller.has_tag("stealth") or observer_team == team


func apply_status(definition: StatusEffectDefinition, source_actor_id := 0) -> bool:
	return status_controller.apply(definition, source_actor_id)


func apply_status_after(status: StatusEffectDefinition, delay: float, source_actor_id := 0) -> void:
	pending_statuses.append({"status": status, "remaining": maxf(delay, 0.0), "source": source_actor_id})


func _update_pending_statuses(delta: float) -> void:
	for index in range(pending_statuses.size() - 1, -1, -1):
		var entry := pending_statuses[index]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			apply_status(entry["status"] as StatusEffectDefinition, int(entry["source"]))
			pending_statuses.remove_at(index)
		else:
			pending_statuses[index] = entry


func queue_delayed_missing_hp_damage(source: CombatActor, ability: AbilityDefinition, attack_id: int) -> void:
	pending_damage_events.append({
		"source": source,
		"source_id": source.battle_id,
		"ability": ability,
		"attack_id": attack_id,
		"remaining": ability.target_delayed_damage_delay,
		"ratio": ability.target_delayed_missing_hp_ratio,
	})
	_spawn_bear_poison_mark(ability.target_delayed_damage_delay)


func _update_pending_damage_events(delta: float) -> void:
	for index in range(pending_damage_events.size() - 1, -1, -1):
		var entry := pending_damage_events[index]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) > 0.0:
			pending_damage_events[index] = entry
			continue
		pending_damage_events.remove_at(index)
		if is_defeated:
			continue
		var source = entry.get("source")
		if not source is CombatActor or not is_instance_valid(source):
			continue
		var ability := entry["ability"] as AbilityDefinition
		var damage := (definition.max_hp - hp) * float(entry["ratio"])
		if damage <= 0.0:
			continue
		var direction: Vector3 = global_position - source.global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			direction = source.facing
		var hp_before := hp
		if receive_hit(source, ability, direction.normalized(), int(entry["attack_id"]), damage):
			source.on_ability_hit(ability, minf(hp_before, damage))
			_spawn_bear_poison_burst()


func auto_face_nearest(radius: float) -> bool:
	var nearest: CombatActor
	var best := radius * radius
	for value in get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate == self or candidate.team == team or not candidate.is_targetable() or not candidate.is_visible_to(team) or candidate.is_defeated:
				continue
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance <= best:
				nearest = candidate
				best = distance
	if nearest == null:
		return false
	var direction := nearest.global_position - global_position
	direction.y = 0.0
	facing = direction.normalized()
	return true


func _bear_basic_for_current_range(fallback: AbilityDefinition) -> AbilityDefinition:
	var nearest: CombatActor
	var best := fallback.auto_target_radius * fallback.auto_target_radius
	var pointed: CombatActor
	var pointed_distance := INF
	for value in get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate == self or candidate.team == team or candidate.is_defeated or not candidate.is_visible_to(team):
				continue
			var offset := candidate.global_position - global_position
			offset.y = 0.0
			var distance := offset.length_squared()
			if distance <= best:
				nearest = candidate
				best = distance
			var point_offset := candidate.global_position - pending_ability_target
			point_offset.y = 0.0
			var point_distance := point_offset.length_squared()
			var point_radius := candidate.definition.body_radius + 0.35
			if distance <= fallback.auto_target_radius * fallback.auto_target_radius and point_distance <= point_radius * point_radius and point_distance < pointed_distance:
				pointed = candidate
				pointed_distance = point_distance
	if pointed != null:
		nearest = pointed
		var pointed_offset := pointed.global_position - global_position
		pointed_offset.y = 0.0
		best = pointed_offset.length_squared()
	# Skill ranges are measured to the target Hurtbox edge. This matches the
	# hitbox overlap itself and avoids selecting the ranged branch when two
	# characters are already touching but their centres remain over 100 yards apart.
	var melee = definition.ability_variants.get("basic_melee")
	if nearest != null and melee is AbilityDefinition:
		var melee_reach := (melee as AbilityDefinition).hitbox_radius + nearest.definition.body_radius * 0.86
		if sqrt(best) <= melee_reach:
			return melee as AbilityDefinition
	return fallback


func _bear_find_ultimate_target(max_range: float) -> CombatActor:
	var nearest: CombatActor
	var nearest_distance := max_range * max_range
	var pointed: CombatActor
	var pointed_distance := 1.10 * 1.10
	for value in get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate == self or candidate.team == team or candidate.is_defeated or not candidate.is_targetable() or not candidate.is_visible_to(team):
				continue
			var source_distance := global_position.distance_squared_to(candidate.global_position)
			if source_distance > max_range * max_range:
				continue
			var point_distance := pending_ability_target.distance_squared_to(candidate.global_position)
			if point_distance <= pointed_distance:
				pointed = candidate
				pointed_distance = point_distance
			if source_distance <= nearest_distance:
				nearest = candidate
				nearest_distance = source_distance
	return pointed if pointed != null else nearest


func _activate_bear_ambush(ability: AbilityDefinition, attack_id: int) -> void:
	var target := bear_ultimate_target
	bear_ultimate_target = null
	if target == null or not is_instance_valid(target) or target.is_defeated or not target.is_targetable():
		return
	var old_position := global_position
	_spawn_bear_afterimage_at(old_position, ability)
	var behind := Vector3(target.facing.x, 0.0, target.facing.z).normalized()
	if behind.length_squared() <= 0.001:
		behind = -facing
	var landing := target.global_position - behind * (target.definition.body_radius + definition.body_radius + 0.16)
	landing.y = global_position.y
	global_position = _bear_safe_ambush_position(landing, target.global_position)
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.001:
		facing = to_target.normalized()
	_spawn_bear_teleport_trail(old_position, global_position, ability)
	_spawn_bear_afterimage_at(global_position, ability)
	var hp_before := target.hp
	if target.receive_hit(self, ability, facing, attack_id, ability.damage):
		on_ability_hit(ability, minf(hp_before, ability.damage))


func _bear_safe_ambush_position(preferred: Vector3, target_position: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius = definition.body_radius * 0.88
	for offset_value in [Vector3.ZERO, Vector3(0.42, 0.0, 0.0), Vector3(-0.42, 0.0, 0.0), Vector3(0.0, 0.0, 0.42), Vector3(0.0, 0.0, -0.42)]:
		var candidate: Vector3 = preferred + Vector3(offset_value)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * definition.body_radius)
		query.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	var fallback := target_position - (target_position - global_position).normalized() * 0.75
	fallback.y = global_position.y
	return fallback


func begin_grapple_pull(endpoint: Vector3) -> void:
	if is_defeated:
		return
	dash_start = global_position
	dash_end = Vector3(endpoint.x, global_position.y, endpoint.z)
	var distance := dash_start.distance_to(dash_end)
	if distance <= 0.05:
		return
	dash_duration = clampf(distance / 10.5, 0.10, 0.48)
	dash_remaining = dash_duration
	dash_phasing = true
	bear_grapple_pull_remaining = dash_duration
	if status_controller.has_tag("stealth"):
		status_controller.remove("bear_stealth")
	_spawn_bear_pull_streaks(dash_start, dash_end)


func _spawn_nailoong_fireball(ability: AbilityDefinition) -> void:
	var fan_offsets := [-22.0, -11.0, 0.0, 11.0, 22.0, 6.0, -16.0, 16.0, -6.0, 0.0]
	var angle := deg_to_rad(float(fan_offsets[nailoong_fire_emit_index % fan_offsets.size()]))
	nailoong_fire_emit_index += 1
	var shot_direction := Basis(Vector3.UP, angle) * facing
	shot_direction.y = 0.0
	shot_direction = shot_direction.normalized()
	var projectile := ProjectileScript.new() as CombatProjectile
	get_parent().add_child(projectile)
	projectile.global_position = global_position + shot_direction * 0.52 + Vector3.UP * ability.projectile_height
	var attack_id := next_attack_id
	next_attack_id += 1
	projectile.configure(self, ability, shot_direction, attack_id)


func _start_nailoong_leap(ability: AbilityDefinition, attack_id: int) -> void:
	var direction := pending_ability_target - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = facing
	var distance := minf(direction.length(), 3.0)
	direction = direction.normalized()
	facing = direction
	nailoong_leap_start = global_position
	nailoong_leap_end = _safe_nailoong_leap_endpoint(global_position + direction * distance)
	nailoong_leap_end.y = global_position.y
	nailoong_leap_duration = maxf(ability.active, 0.32)
	nailoong_leap_remaining = nailoong_leap_duration
	nailoong_leap_ability = ability
	nailoong_leap_attack_id = attack_id
	_spawn_nailoong_takeoff_ring()


func _safe_nailoong_leap_endpoint(preferred: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius = definition.body_radius * 0.88
	var direction := preferred - global_position
	direction.y = 0.0
	for step in range(13):
		var ratio := 1.0 - float(step) / 12.0
		var candidate := global_position + direction * ratio
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * definition.body_radius)
		query.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return global_position


func _finish_nailoong_leap() -> void:
	if nailoong_leap_ability == null:
		return
	var hitbox := AttackHitboxScript.new() as AttackHitbox
	add_child(hitbox)
	hitbox.configure(self, nailoong_leap_ability, nailoong_leap_attack_id)
	_spawn_nailoong_landing_wave(nailoong_leap_ability.hitbox_radius)
	nailoong_leap_ability = null
	nailoong_leap_attack_id = 0


func _update_nailoong_regeneration(delta: float) -> void:
	if nailoong_regen_ticks_remaining <= 0:
		return
	if is_defeated:
		nailoong_regen_ticks_remaining = 0
		return
	nailoong_regen_tick_remaining -= delta
	while nailoong_regen_tick_remaining <= 0.0 and nailoong_regen_ticks_remaining > 0:
		hp = minf(definition.max_hp, hp + 8.0)
		nailoong_regen_ticks_remaining -= 1
		nailoong_regen_tick_remaining += 0.5
		resource_changed.emit(self)
		_spawn_nailoong_heal_tick()


func _update_chu_ying_charges(delta: float) -> void:
	if definition == null or definition.hero_id != "chu_ying" or chu_ying_q_charges >= 3:
		return
	chu_ying_q_recharge_remaining -= delta
	while chu_ying_q_recharge_remaining <= 0.0 and chu_ying_q_charges < 3:
		chu_ying_q_charges += 1
		energy = float(chu_ying_q_charges)
		if chu_ying_q_charges < 3:
			chu_ying_q_recharge_remaining += 5.0
		else:
			chu_ying_q_recharge_remaining = 0.0
		resource_changed.emit(self)


func _activate_chu_ying_basic(ability: AbilityDefinition, attack_id: int) -> void:
	var target := _find_enemy_near_ability_point(ability.target_required_range)
	if target == null:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		facing = direction.normalized()
	var projectile := ProjectileScript.new() as CombatProjectile
	get_parent().add_child(projectile)
	projectile.global_position = global_position + facing * 0.48 + Vector3.UP * ability.projectile_height
	projectile.configure(self, ability, facing, attack_id, target)


func _activate_chu_ying_q(ability: AbilityDefinition, attack_id: int) -> void:
	var landing := _clamped_ability_point(ability.target_required_range)
	var stone := ChuYingStoneScript.new() as ChuYingStone
	get_parent().add_child(stone)
	stone.configure(self, ability, landing, attack_id)


func _activate_chu_ying_board(ability: AbilityDefinition, attack_id: int) -> void:
	var board_position := _clamped_ability_point(ability.target_required_range)
	_damage_circle_at(board_position, ability.hitbox_radius, ability, attack_id)
	_spawn_chu_ying_board_visual(board_position)
	for value in get_tree().get_nodes_in_group("chu_ying_stones"):
		if value is ChuYingStone:
			var stone := value as ChuYingStone
			if stone.source != null and stone.source.team == team and stone.can_be_pulled() and stone.global_position.distance_squared_to(board_position) <= 25.0:
				stone.fly_to(board_position, ability)


func _activate_chu_ying_teleport(ability: AbilityDefinition) -> void:
	var old_position := global_position
	var requested := _clamped_ability_point(ability.target_required_range)
	var destination := _safe_chu_ying_teleport_endpoint(requested)
	_spawn_chu_ying_teleport_ghost(old_position)
	global_position = destination
	velocity = Vector3.ZERO
	_spawn_chu_ying_teleport_ghost(destination)


func _activate_chu_ying_barrier(ability: AbilityDefinition, attack_id: int) -> void:
	var endpoint := _clamped_ability_point(ability.target_required_range)
	var origin := Vector3(global_position.x, 0.0, global_position.z)
	# Origin and endpoint are opposite corners. Keep each full side at least one
	# world unit (100 yards), rather than turning the diagonal into a square.
	var center := (origin + endpoint) * 0.5
	var half_extents := Vector2(
		maxf(absf(endpoint.x - origin.x) * 0.5, 0.5),
		maxf(absf(endpoint.z - origin.z) * 0.5, 0.5)
	)
	_damage_box_at(center, half_extents, ability, attack_id)
	var barrier := ChuYingBarrierScript.new() as ChuYingBarrier
	get_parent().add_child(barrier)
	barrier.configure(self, center, half_extents, attack_id)


func _find_enemy_near_ability_point(max_range: float) -> CombatActor:
	var pointed: CombatActor
	var pointed_distance := 1.0
	var nearest: CombatActor
	var nearest_distance := max_range * max_range
	for value in get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate == self or candidate.team == team or candidate.is_defeated or not candidate.is_targetable() or not candidate.is_visible_to(team):
				continue
			var source_offset := candidate.global_position - global_position
			source_offset.y = 0.0
			var source_distance := source_offset.length_squared()
			if source_distance > max_range * max_range:
				continue
			var point_offset := candidate.global_position - pending_ability_target
			point_offset.y = 0.0
			var point_distance := point_offset.length_squared()
			if point_distance < pointed_distance:
				pointed = candidate
				pointed_distance = point_distance
			if source_distance < nearest_distance:
				nearest = candidate
				nearest_distance = source_distance
	return pointed if pointed != null else nearest


func _clamped_ability_point(max_range: float) -> Vector3:
	var offset := pending_ability_target - global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = facing * minf(0.8, max_range)
	elif offset.length() > max_range:
		offset = offset.normalized() * max_range
	return Vector3(global_position.x + offset.x, 0.07, global_position.z + offset.z)


func _safe_chu_ying_teleport_endpoint(preferred: Vector3) -> Vector3:
	var shape := SphereShape3D.new()
	shape.radius = definition.body_radius * 0.88
	var offset := preferred - global_position
	offset.y = 0.0
	for step in range(21):
		var ratio := 1.0 - float(step) / 20.0
		var candidate := global_position + offset * ratio
		candidate.y = global_position.y
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * definition.body_radius)
		query.collision_mask = 1
		var ground_query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 2.2, candidate + Vector3.DOWN * 0.8, 1)
		ground_query.collide_with_areas = false
		ground_query.collide_with_bodies = true
		var has_ground := not get_world_3d().direct_space_state.intersect_ray(ground_query).is_empty()
		if has_ground and get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return global_position


func _damage_circle_at(center: Vector3, radius: float, ability: AbilityDefinition, attack_id: int) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 2.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(center.x, 1.0, center.z))
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_3d().direct_space_state.intersect_shape(query, 48):
		var collider = result.get("collider")
		var target = collider.get_meta("combat_actor", null) if collider is Area3D else null
		if not target is CombatActor or target == self or target.team == team:
			continue
		var combat_target := target as CombatActor
		var hp_before: float = combat_target.hp
		var direction: Vector3 = combat_target.global_position - center
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			direction = facing
		if combat_target.receive_hit(self, ability, direction.normalized(), attack_id, ability.damage):
			on_ability_hit(ability, minf(hp_before, ability.damage))


func _damage_box_at(center: Vector3, half_extents: Vector2, ability: AbilityDefinition, attack_id: int) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(half_extents.x * 2.0, 2.2, half_extents.y * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(center.x, 1.0, center.z))
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_3d().direct_space_state.intersect_shape(query, 48):
		var collider = result.get("collider")
		var target = collider.get_meta("combat_actor", null) if collider is Area3D else null
		if not target is CombatActor or target == self or target.team == team:
			continue
		var combat_target := target as CombatActor
		var hp_before: float = combat_target.hp
		var direction: Vector3 = combat_target.global_position - center
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			direction = facing
		if combat_target.receive_hit(self, ability, direction.normalized(), attack_id, ability.damage):
			on_ability_hit(ability, minf(hp_before, ability.damage))


func _has_enemy_in_radius(radius: float) -> bool:
	for value in get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate != self and candidate.team != team and not candidate.is_defeated and global_position.distance_squared_to(candidate.global_position) <= radius * radius:
				return true
	return false


func on_ability_hit(ability: AbilityDefinition, dealt_damage := 0.0) -> void:
	gain_energy(ability.energy_on_hit)
	var healing := ability.healing_on_hit + dealt_damage * ability.lifesteal_ratio
	if healing > 0.0 and not is_defeated:
		hp = minf(definition.max_hp, hp + healing)
		resource_changed.emit(self)
	if ability.refresh_cooldown_on_hit:
		cooldowns[ability.ability_id] = 0.0


func modify_outgoing_damage(target: CombatActor, ability: AbilityDefinition, base_damage: float) -> float:
	if definition.hero_id != "bear_grylls_jungler" or base_damage <= 0.0 or target == null:
		return base_damage
	var to_source := global_position - target.global_position
	to_source.y = 0.0
	if to_source.length_squared() <= 0.001:
		return base_damage
	var target_forward := Vector3(target.facing.x, 0.0, target.facing.z).normalized()
	if target_forward.length_squared() > 0.001 and target_forward.dot(to_source.normalized()) <= -0.5:
		_spawn_bear_backstab_flash(target)
		return base_damage * 2.0
	return base_damage


func on_killed_actor(_target: CombatActor, ability: AbilityDefinition) -> void:
	if definition.hero_id != "bear_grylls_jungler" or is_defeated:
		return
	hp = minf(definition.max_hp, hp + 30.0)
	if ability != null and ability.ability_id == "ultimate":
		cooldowns["ultimate"] = 0.0
	resource_changed.emit(self)


func _blocks_attack_from(source: CombatActor) -> bool:
	if current_ability == null or not current_ability.blocks_front_damage or ability_phase != "active" or source == null:
		return false
	var to_source := source.global_position - global_position
	to_source.y = 0.0
	if to_source.length_squared() <= 0.001:
		return true
	var threshold := cos(deg_to_rad(current_ability.front_block_degrees * 0.5))
	return facing.dot(to_source.normalized()) >= threshold


func _enter_transformed_form() -> void:
	if definition.transformed_sprite_texture == null or definition.transform_duration <= 0.0:
		return
	transformed = true
	transformed_remaining = definition.transform_duration
	sprite.texture = definition.transformed_sprite_texture
	sprite.pixel_size = definition.transformed_sprite_pixel_size if definition.transformed_sprite_pixel_size > 0.0 else base_sprite_pixel_size
	flash_remaining = 0.24


func _exit_transformed_form() -> void:
	transformed = false
	transformed_remaining = 0.0
	sprite.texture = base_sprite_texture
	sprite.pixel_size = base_sprite_pixel_size
	flash_remaining = 0.24
	var ultimate := definition.ability_by_id("ultimate")
	if ultimate != null:
		cooldowns["ultimate"] = ultimate.cooldown
	if current_ability != null and definition.transformed_ability_by_id(current_ability.ability_id) == current_ability:
		_cancel_current_ability()
	resource_changed.emit(self)


func _spawn_block_flash() -> void:
	var visual := MeshInstance3D.new()
	visual.top_level = true
	get_parent().add_child(visual)
	visual.global_position = global_position + facing * 0.55 + Vector3.UP * 0.85
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.material = _vfx_material(Color(0.72, 0.9, 1.0, 0.8))
	visual.mesh = mesh
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 2.2, 0.12)
	tween.parallel().tween_property(visual, "transparency", 1.0, 0.12)
	tween.tween_callback(visual.queue_free)


func on_hitbox_pulse(ability: AbilityDefinition, pulse_index: int) -> void:
	match ability.vfx_id:
		"dimensional_slash":
			_spawn_dimensional_cut(ability, pulse_index)


func _perform_dash(ability: AbilityDefinition) -> void:
	dash_start = global_position
	dash_end = global_position + facing * ability.dash_distance
	dash_duration = maxf(ability.active, 0.08)
	dash_remaining = dash_duration
	dash_phasing = false
	if ability.endpoint_phase_dash:
		var shape := SphereShape3D.new()
		shape.radius = definition.body_radius * 0.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, dash_end + Vector3.UP * definition.body_radius)
		query.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			dash_phasing = true


func _spawn_ability_vfx(ability: AbilityDefinition) -> void:
	if ability.vfx_id.is_empty():
		return
	match ability.vfx_id:
		"katana_sweep", "shield_dog_swing", "shield_guard", "shield_dog_heavy_chop", "swole_punch", "swole_dash", "sword_shield_transform":
			return
		"shield_bash":
			_spawn_shield_bash_ghost(ability)
			return
		"sword_wave", "multi_slash":
			return
		"bear_throw_knife", "bear_grapple", "bear_ambush":
			return
		"bear_melee_knife":
			_spawn_bear_melee_slash()
			return
		"bear_poison_mark":
			_spawn_bear_poison_sweep(ability.hitbox_radius)
			return
		"bear_stealth":
			_spawn_bear_stealth_puff()
			return
		"dash_slash":
			return
		"dimensional_slash":
			return
		"swole_slam":
			_spawn_swole_slam_wave(ability)
			return
		"nailoong_tail_sweep":
			_spawn_nailoong_tail_sweep(ability.hitbox_radius)
			return
		"nailoong_roll":
			_spawn_nailoong_roll_dust()
			return
		"nailoong_fire_breath":
			_spawn_nailoong_fire_muzzle()
			return
		"nailoong_leap":
			return
		"nailoong_laugh":
			_spawn_nailoong_laugh_wave()
			return
	var visual := MeshInstance3D.new()
	visual.top_level = true
	get_parent().add_child(visual)
	visual.global_position = Vector3(global_position.x, 0.055, global_position.z) + facing * minf(ability.hitbox_distance, 0.8)
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


func _spawn_nailoong_tail_sweep(radius: float) -> void:
	var ring := _spawn_nailoong_ring(Vector3(global_position.x, 0.065, global_position.z), radius * 0.80, radius, Color(0.96, 0.99, 1.0, 0.52))
	ring.name = "NailoongBasicShockwave"
	ring.scale = Vector3.ONE * 0.18
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.10, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.26)
	tween.tween_callback(ring.queue_free)


func _spawn_nailoong_roll_dust() -> void:
	var dust := MeshInstance3D.new()
	dust.top_level = true
	dust.add_to_group("transient_combat_vfx")
	get_parent().add_child(dust)
	dust.global_position = Vector3(global_position.x, 0.13, global_position.z) - nailoong_roll_direction * 0.32
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


func _spawn_nailoong_bounce_flash(position: Vector3) -> void:
	var flash := _spawn_nailoong_ring(position + Vector3.UP * 0.55, 0.12, 0.22, Color(1.0, 0.93, 0.45, 0.86))
	flash.rotation.x = PI * 0.5
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.8, 0.14)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.14)
	tween.tween_callback(flash.queue_free)


func _spawn_nailoong_fire_muzzle() -> void:
	var ring := _spawn_nailoong_ring(global_position + facing * 0.52 + Vector3.UP * 0.78, 0.08, 0.16, Color(1.0, 0.34, 0.06, 0.86))
	ring.rotation.x = PI * 0.5
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.0, 0.16)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.18)
	tween.tween_callback(ring.queue_free)


func _spawn_nailoong_takeoff_ring() -> void:
	var ring := _spawn_nailoong_ring(Vector3(global_position.x, 0.05, global_position.z), 0.24, 0.42, Color(1.0, 0.88, 0.30, 0.62))
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.9, 0.24)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.24)
	tween.tween_callback(ring.queue_free)


func _spawn_nailoong_landing_wave(radius: float) -> void:
	var ring := _spawn_nailoong_ring(Vector3(global_position.x, 0.06, global_position.z), radius * 0.78, radius, Color(0.96, 0.99, 1.0, 0.56))
	ring.name = "NailoongLandingShockwave"
	ring.scale = Vector3(0.18, 0.18, 0.18)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.18, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.32)
	tween.tween_callback(ring.queue_free)


func _spawn_nailoong_laugh_wave() -> void:
	for index in range(3):
		var ring := _spawn_nailoong_ring(global_position + Vector3.UP * (0.72 + index * 0.18), 0.18, 0.28, Color(0.70, 1.0, 0.40, 0.58 - index * 0.10))
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3.ONE * 0.25
		var tween := ring.create_tween()
		tween.tween_interval(index * 0.08)
		tween.tween_property(ring, "scale", Vector3.ONE * (2.4 + index * 0.35), 0.30)
		tween.parallel().tween_property(ring, "transparency", 1.0, 0.30)
		tween.tween_callback(ring.queue_free)


func _spawn_nailoong_heal_tick() -> void:
	var cross := Node3D.new()
	cross.name = "NailoongHealCross"
	cross.top_level = true
	cross.add_to_group("transient_combat_vfx")
	cross.add_to_group("nailoong_heal_crosses")
	get_parent().add_child(cross)
	var active_camera := get_viewport().get_camera_3d()
	var screen_right := Vector3.RIGHT
	if active_camera != null:
		cross.global_basis = active_camera.global_basis.orthonormalized()
		screen_right = active_camera.global_basis.x.normalized()
	var side := -1.0 if visual_rng.randi_range(0, 1) == 0 else 1.0
	cross.global_position = global_position + screen_right * side * visual_rng.randf_range(0.28, 0.46) + Vector3.UP * visual_rng.randf_range(0.42, 0.64)
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


func _spawn_nailoong_ring(position: Vector3, inner_radius: float, outer_radius: float, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.top_level = true
	visual.add_to_group("transient_combat_vfx")
	get_parent().add_child(visual)
	visual.global_position = position
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 40
	mesh.ring_segments = 8
	mesh.material = _vfx_material(color)
	visual.mesh = mesh
	return visual


func _spawn_chu_ying_board_visual(position: Vector3) -> void:
	var board := Node3D.new()
	board.name = "ChuYingBoardRectangle"
	board.top_level = true
	board.add_to_group("transient_combat_vfx")
	board.add_to_group("chu_ying_board_rectangles")
	get_parent().add_child(board)
	board.global_position = Vector3(position.x, 0.10, position.z)
	var pieces: Array[MeshInstance3D] = []
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(0.78, 0.018, 0.78)
	floor_mesh.material = _vfx_material(Color(0.46, 0.72, 1.0, 0.16))
	floor.mesh = floor_mesh
	board.add_child(floor)
	pieces.append(floor)
	for edge_index in range(4):
		var edge := MeshInstance3D.new()
		var horizontal := edge_index < 2
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.82, 0.028, 0.035) if horizontal else Vector3(0.035, 0.028, 0.82)
		edge_mesh.material = _vfx_material(Color(0.72, 0.88, 1.0, 0.76))
		edge.mesh = edge_mesh
		var side := -1.0 if edge_index % 2 == 0 else 1.0
		edge.position = Vector3(0.0, 0.024, side * 0.40) if horizontal else Vector3(side * 0.40, 0.024, 0.0)
		board.add_child(edge)
		pieces.append(edge)
	_add_chu_ying_light_walls(board, Vector2(0.41, 0.41), 0.65, pieces)
	board.scale = Vector3.ONE * 0.25
	var tween := board.create_tween()
	tween.tween_property(board, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.48)
	for piece in pieces:
		tween.parallel().tween_property(piece, "transparency", 1.0, 0.20)
	tween.tween_callback(board.queue_free)


func _add_chu_ying_light_walls(anchor: Node3D, half_extents: Vector2, height: float, pieces: Array[MeshInstance3D]) -> void:
	for wall_index in range(4):
		var wall := MeshInstance3D.new()
		wall.name = "ChuYingLightWall"
		wall.add_to_group("chu_ying_light_walls")
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var along_x := wall_index < 2
		var quad := QuadMesh.new()
		quad.size = Vector2(half_extents.x * 2.0, height) if along_x else Vector2(half_extents.y * 2.0, height)
		quad.material = _chu_ying_light_wall_material()
		wall.mesh = quad
		var side := -1.0 if wall_index % 2 == 0 else 1.0
		wall.position = Vector3(0.0, height * 0.5, side * half_extents.y) if along_x else Vector3(side * half_extents.x, height * 0.5, 0.0)
		wall.rotation.y = 0.0 if along_x else PI * 0.5
		anchor.add_child(wall)
		pieces.append(wall)


func _chu_ying_light_wall_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
	float bottom_to_top = smoothstep(0.0, 0.92, UV.y);
	vec3 glow = vec3(0.56, 0.78, 1.0);
	ALBEDO = glow;
	EMISSION = glow * 1.8;
	ALPHA = bottom_to_top * 0.34;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _spawn_chu_ying_teleport_charge(duration: float) -> void:
	var circle := Node3D.new()
	circle.name = "ChuYingTeleportChargeCircle"
	circle.top_level = true
	circle.add_to_group("transient_combat_vfx")
	circle.add_to_group("chu_ying_teleport_charge")
	get_parent().add_child(circle)
	circle.global_position = Vector3(global_position.x, 0.052, global_position.z)
	for ring_index in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.50 - ring_index * 0.15
		torus.outer_radius = 0.56 - ring_index * 0.15
		torus.rings = 40
		torus.ring_segments = 7
		torus.material = _vfx_material(Color(0.82, 0.92, 1.0, 0.42))
		ring.mesh = torus
		circle.add_child(ring)
	for spoke_index in range(8):
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(0.035, 0.018, 0.48)
		spoke_mesh.material = _vfx_material(Color(0.78, 0.90, 1.0, 0.26))
		spoke.mesh = spoke_mesh
		spoke.position = Vector3(sin(TAU * spoke_index / 8.0), 0.0, cos(TAU * spoke_index / 8.0)) * 0.25
		spoke.rotation.y = TAU * spoke_index / 8.0
		circle.add_child(spoke)
	var spin := circle.create_tween()
	spin.tween_property(circle, "rotation:y", TAU * 1.35, duration)
	spin.parallel().tween_property(circle, "scale", Vector3(0.82, 1.0, 0.82), duration)
	spin.tween_callback(circle.queue_free)
	_spawn_concentration_rings(0.78, duration, "ChuYingTeleportFocus")


func _spawn_concentration_rings(radius: float, duration: float, effect_name: String) -> void:
	var count := maxi(3, ceili(duration / 0.13))
	for index in range(count):
		var ring := MeshInstance3D.new()
		ring.name = effect_name
		ring.top_level = true
		ring.add_to_group("transient_combat_vfx")
		ring.add_to_group("concentration_rings")
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(ring)
		ring.global_position = Vector3(global_position.x, 0.072 + index * 0.002, global_position.z)
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


func _spawn_chu_ying_teleport_ghost(position: Vector3) -> void:
	_spawn_chu_ying_teleport_column(position)
	var ghost := Sprite3D.new()
	ghost.top_level = true
	ghost.add_to_group("transient_combat_vfx")
	get_parent().add_child(ghost)
	ghost.texture = base_sprite_texture
	ghost.pixel_size = base_sprite_pixel_size
	ghost.global_position = position + Vector3.UP * definition.sprite_y
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(0.72, 0.88, 1.0, 0.58)
	ghost.no_depth_test = false
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "scale", Vector3(1.18, 1.08, 1.0), 0.24)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ghost.queue_free)


func _spawn_chu_ying_teleport_column(position: Vector3) -> void:
	var column := MeshInstance3D.new()
	column.name = "ChuYingTeleportColumn"
	column.top_level = true
	column.add_to_group("transient_combat_vfx")
	column.add_to_group("chu_ying_teleport_columns")
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(column)
	column.global_position = Vector3(position.x, 1.25, position.z)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.23
	mesh.height = 2.5
	mesh.radial_segments = 24
	mesh.material = _vfx_material(Color(0.72, 0.88, 1.0, 0.34))
	column.mesh = mesh
	column.scale = Vector3(0.22, 0.65, 0.22)
	var tween := column.create_tween()
	tween.tween_property(column, "scale", Vector3(1.0, 1.0, 1.0), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(column, "scale", Vector3(0.12, 1.10, 0.12), 0.26)
	tween.parallel().tween_property(column, "transparency", 1.0, 0.26)
	tween.tween_callback(column.queue_free)


func _spawn_bear_melee_slash() -> void:
	for index in range(3):
		var slash := MeshInstance3D.new()
		slash.top_level = true
		slash.add_to_group("transient_combat_vfx")
		get_parent().add_child(slash)
		slash.global_position = global_position + facing * (0.58 + index * 0.10) + Vector3.UP * (0.72 + index * 0.11)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.66 - index * 0.10, 0.025, 0.055)
		mesh.material = _vfx_material(Color(0.88, 0.96, 0.91, 0.72 - index * 0.14))
		slash.mesh = mesh
		slash.rotation.y = atan2(-facing.x, -facing.z)
		slash.rotation.z = -0.50 + index * 0.24
		var tween := slash.create_tween()
		tween.tween_property(slash, "scale:x", 1.65, 0.10)
		tween.parallel().tween_property(slash, "transparency", 1.0, 0.16)
		tween.tween_callback(slash.queue_free)


func _spawn_bear_poison_sweep(radius: float) -> void:
	# Five independently orbiting horizontal rings form a readable white whirlwind.
	# Their centres are deliberately offset from the actor so the silhouette does
	# not collapse into a stack of perfectly concentric circles.
	for index in range(5):
		var orbit := Node3D.new()
		orbit.name = "BearWhirlwindOrbit_%d" % index
		orbit.top_level = true
		orbit.add_to_group("transient_combat_vfx")
		get_parent().add_child(orbit)
		orbit.global_position = Vector3(global_position.x, 0.0, global_position.z)
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


func _spawn_bear_stealth_puff() -> void:
	for index in range(10):
		var puff := MeshInstance3D.new()
		puff.top_level = true
		puff.add_to_group("transient_combat_vfx")
		get_parent().add_child(puff)
		var angle := TAU * float(index) / 10.0
		puff.global_position = global_position + Vector3(cos(angle), 0.25 + 0.08 * float(index % 3), sin(angle)) * 0.36
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


func _spawn_bear_poison_mark(duration: float) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "BearPoisonMark"
	mark.add_to_group("transient_combat_vfx")
	mark.position = Vector3(0.0, definition.body_height + 0.34, 0.0)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.25
	ring.rings = 24
	ring.ring_segments = 7
	ring.material = _vfx_material(Color(0.38, 1.0, 0.24, 0.86))
	mark.mesh = ring
	add_child(mark)
	var spin := mark.create_tween()
	spin.tween_property(mark, "rotation:y", TAU * 3.0, duration)
	var lifetime := mark.create_tween()
	lifetime.tween_interval(duration * 0.72)
	lifetime.tween_property(mark, "scale", Vector3.ONE * 1.8, duration * 0.28)
	lifetime.parallel().tween_property(mark, "transparency", 1.0, duration * 0.28)
	lifetime.tween_callback(mark.queue_free)


func _spawn_bear_poison_burst() -> void:
	var burst := MeshInstance3D.new()
	burst.top_level = true
	burst.add_to_group("transient_combat_vfx")
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector3.UP * 0.82
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.material = _vfx_material(Color(0.35, 1.0, 0.20, 0.62))
	burst.mesh = sphere
	var tween := burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 2.8, 0.24)
	tween.parallel().tween_property(burst, "transparency", 1.0, 0.24)
	tween.tween_callback(burst.queue_free)


func _spawn_bear_backstab_flash(target: CombatActor) -> void:
	for index in range(2):
		var slash := MeshInstance3D.new()
		slash.top_level = true
		slash.add_to_group("transient_combat_vfx")
		get_parent().add_child(slash)
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


func _spawn_bear_afterimage_at(position: Vector3, ability: AbilityDefinition) -> void:
	var ghost := Sprite3D.new()
	ghost.top_level = true
	ghost.add_to_group("transient_combat_vfx")
	var action_texture = definition.action_sprite_textures.get(ability.vfx_id)
	ghost.texture = action_texture as Texture2D if action_texture is Texture2D else base_sprite_texture
	ghost.pixel_size = base_sprite_pixel_size
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.modulate = Color(0.68, 0.94, 0.75, 0.46)
	ghost.flip_h = facing.x < -0.05 if definition.sprite_faces_right else facing.x >= -0.05
	get_parent().add_child(ghost)
	ghost.global_position = position + Vector3.UP * definition.sprite_y
	_set_visual_layer_angle(ghost, 0.0)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "scale", Vector3.ONE * 1.10, 0.24)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ghost.queue_free)


func _spawn_bear_teleport_trail(start: Vector3, finish: Vector3, ability: AbilityDefinition) -> void:
	for index in range(1, 5):
		var position := start.lerp(finish, float(index) / 5.0)
		_spawn_bear_afterimage_at(position, ability)
	var arrival := MeshInstance3D.new()
	arrival.top_level = true
	arrival.add_to_group("transient_combat_vfx")
	get_parent().add_child(arrival)
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


func _spawn_bear_pull_streaks(start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	for index in range(4):
		var streak := MeshInstance3D.new()
		streak.top_level = true
		streak.add_to_group("transient_combat_vfx")
		get_parent().add_child(streak)
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


func _spawn_swole_slam_wave(ability: AbilityDefinition) -> void:
	var wave := MeshInstance3D.new()
	wave.name = "SwoleSlamShockwave"
	wave.top_level = true
	wave.add_to_group("transient_combat_vfx")
	get_parent().add_child(wave)
	wave.global_position = Vector3(global_position.x, 0.08, global_position.z)
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


func _spawn_shield_bash_ghost(ability: AbilityDefinition) -> void:
	var source_shield := visual_layer_sprites.get("shield_dog_shield") as Sprite3D
	if source_shield == null:
		return
	var ghost := Sprite3D.new()
	ghost.name = "ShieldBashGhost"
	ghost.top_level = true
	ghost.add_to_group("transient_combat_vfx")
	ghost.texture = source_shield.texture
	ghost.pixel_size = source_shield.pixel_size
	ghost.offset = source_shield.offset
	ghost.flip_h = facing.x < -0.05
	if ghost.flip_h:
		ghost.offset.x = -ghost.offset.x
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.modulate = Color(0.78, 0.91, 1.0, 0.60)
	ghost.set_meta("initial_opacity", ghost.modulate.a)
	get_parent().add_child(ghost)
	var direction := facing.normalized()
	var start := global_position + direction * 0.26 + Vector3.UP * 0.86
	var finish := global_position + direction * (ability.hitbox_distance + ability.hitbox_size.z * 0.5) + Vector3.UP * 0.86
	ghost.global_position = start
	var active_camera := get_viewport().get_camera_3d()
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


func _spawn_magic_circle(ability: AbilityDefinition, duration: float) -> void:
	if is_instance_valid(active_magic_circle):
		active_magic_circle.queue_free()
	var anchor := Node3D.new()
	anchor.name = "DimensionalMagicCircle"
	anchor.top_level = true
	get_parent().add_child(anchor)
	active_magic_circle = anchor
	anchor.global_position = Vector3(global_position.x, 0.032, global_position.z)
	var mirror := MeshInstance3D.new()
	mirror.name = "Mirror"
	var mirror_mesh := CylinderMesh.new()
	mirror_mesh.top_radius = ability.hitbox_radius * 1.02
	mirror_mesh.bottom_radius = ability.hitbox_radius * 1.02
	mirror_mesh.height = 0.018
	mirror_mesh.radial_segments = 64
	var mirror_material := _material(Color(0.025, 0.055, 0.10, 0.075), true, true)
	mirror_material.metallic = 0.92
	mirror_material.roughness = 0.12
	mirror_mesh.material = mirror_material
	mirror.mesh = mirror_mesh
	anchor.add_child(mirror)
	var circle := MeshInstance3D.new()
	circle.name = "Circle"
	var quad := QuadMesh.new()
	quad.size = Vector2(ability.hitbox_radius * 2.08, ability.hitbox_radius * 2.08)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D circle_texture : source_color, filter_linear_mipmap;
uniform float opacity = 0.70;
void fragment() {
	vec4 c = texture(circle_texture, UV);
	float lightness = max(c.r, max(c.g, c.b));
	ALBEDO = c.rgb;
	EMISSION = c.rgb * 2.8;
	ALPHA = smoothstep(0.035, 0.22, lightness) * opacity;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("circle_texture", CHEEMS_MAGIC_CIRCLE)
	quad.material = material
	circle.mesh = quad
	circle.rotation.x = -PI * 0.5
	circle.position.y = 0.012
	circle.scale = Vector3.ONE
	anchor.add_child(circle)
	var spin := circle.create_tween()
	spin.tween_property(circle, "rotation:z", TAU * 0.16, duration)
	magic_circle_lifetime_tween = anchor.create_tween()
	magic_circle_lifetime_tween.tween_interval(maxf(0.0, duration - 0.20))
	magic_circle_lifetime_tween.tween_property(circle, "transparency", 1.0, 0.20)
	magic_circle_lifetime_tween.parallel().tween_property(mirror, "transparency", 1.0, 0.20)
	magic_circle_lifetime_tween.tween_callback(anchor.queue_free)


func _dismiss_magic_circle(duration: float) -> void:
	if not is_instance_valid(active_magic_circle):
		active_magic_circle = null
		return
	if magic_circle_lifetime_tween != null and magic_circle_lifetime_tween.is_valid():
		magic_circle_lifetime_tween.kill()
	var anchor := active_magic_circle
	active_magic_circle = null
	if duration <= 0.0:
		anchor.queue_free()
		return
	var circle := anchor.get_node_or_null("Circle") as MeshInstance3D
	var mirror := anchor.get_node_or_null("Mirror") as MeshInstance3D
	var tween := anchor.create_tween()
	if circle != null:
		tween.tween_property(circle, "transparency", 1.0, duration)
	if mirror != null:
		tween.parallel().tween_property(mirror, "transparency", 1.0, duration)
	tween.tween_callback(anchor.queue_free)


func _spawn_horizontal_slash(ability: AbilityDefinition) -> void:
	if ability.vfx_id != "multi_slash":
		return
	var slash := MeshInstance3D.new()
	slash.name = "MultiSlashVisual"
	slash.add_to_group("transient_combat_vfx")
	slash.top_level = true
	get_parent().add_child(slash)
	var side := Vector3(-facing.z, 0.0, facing.x)
	var random_height := visual_rng.randf_range(0.34, 1.16)
	var lateral_offset := visual_rng.randf_range(-0.20, 0.20)
	var start := global_position + facing * 0.52 + side * lateral_offset + Vector3.UP * random_height
	slash.global_position = start
	slash.rotation.y = atan2(-facing.x, -facing.z)
	slash.rotate_object_local(Vector3.FORWARD, deg_to_rad(visual_rng.randf_range(-22.0, 22.0)))
	slash.mesh = _horizontal_crescent_mesh(Color(0.88, 0.96, 1.0, 0.50))
	var visual_scale := visual_rng.randf_range(0.78, 1.08)
	slash.scale = Vector3(0.24, 0.24, 0.24) * visual_scale
	var destination := start + facing * visual_rng.randf_range(1.55, 2.15)
	var move_tween := slash.create_tween()
	move_tween.tween_property(slash, "global_position", destination, 0.28)
	move_tween.parallel().tween_property(slash, "scale", Vector3.ONE * visual_scale, 0.28)
	var fade_tween := slash.create_tween()
	fade_tween.tween_interval(0.12)
	fade_tween.tween_property(slash, "transparency", 1.0, 0.16)
	fade_tween.tween_callback(slash.queue_free)
	_spawn_katana_afterimage()


func _spawn_katana_afterimage() -> void:
	var source_layer := visual_layer_sprites.get("katana_action") as Sprite3D
	if source_layer == null:
		return
	var ghost := Sprite3D.new()
	ghost.add_to_group("transient_combat_vfx")
	ghost.top_level = true
	ghost.texture = source_layer.texture
	ghost.pixel_size = source_layer.pixel_size
	ghost.offset = source_layer.offset
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.flip_h = source_layer.flip_h
	ghost.modulate = Color(0.86, 0.94, 1.0, 0.42)
	get_parent().add_child(ghost)
	ghost.global_position = source_layer.global_position
	_set_visual_layer_angle(ghost, float(source_layer.get_meta("visual_angle", 0.0)))
	ghost.scale = source_layer.scale
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.16)
	tween.tween_callback(ghost.queue_free)


func _spawn_dimensional_cut(ability: AbilityDefinition, pulse_index: int) -> void:
	# Damage still pulses four times, but the cut field is one continuous two-second effect.
	if pulse_index == 1:
		var line_count := 22
		for line_index in range(line_count):
			_spawn_dimensional_line(ability, line_index, line_count)
	var ghost_angle := visual_rng.randf_range(0.0, TAU)
	var ghost_offset := Vector3(cos(ghost_angle), 0.0, sin(ghost_angle)) * visual_rng.randf_range(0.85, 1.55)
	_spawn_afterimage(ghost_offset)
	if pulse_index >= ability.max_hits_per_target:
		_spawn_shatter(ability.hitbox_radius)


func _spawn_dimensional_line(ability: AbilityDefinition, line_index: int, line_count: int) -> void:
	var line := MeshInstance3D.new()
	line.name = "DimensionalCutLine"
	line.add_to_group("transient_combat_vfx")
	line.add_to_group("dimensional_cut_lines")
	line.top_level = true
	get_parent().add_child(line)
	# A golden-angle sequence prevents accidental angular clumps. A power below
	# 0.5 deliberately shifts more line centres toward the outside of the field,
	# avoiding the dense centre produced by a uniformly sampled radius.
	const GOLDEN_ANGLE := 2.39996323
	var radial_rank := (line_index * 7) % maxi(line_count, 1)
	var radial_sample := (float(radial_rank) + visual_rng.randf_range(0.18, 0.82)) / maxf(float(line_count), 1.0)
	var radial_angle := fposmod(float(line_index) * GOLDEN_ANGLE + visual_rng.randf_range(-0.18, 0.18), TAU)
	var radial_distance := ability.hitbox_radius * 0.82 * pow(radial_sample, 0.36)
	var center_offset := Vector3(cos(radial_angle), 0.0, sin(radial_angle)) * radial_distance
	line.global_position = global_position + center_offset + Vector3.UP * visual_rng.randf_range(0.30, 1.42)
	var yaw := visual_rng.randf_range(0.0, TAU)
	var elevation := visual_rng.randf_range(-0.42, 0.42)
	var line_direction := Vector3(cos(yaw) * cos(elevation), sin(elevation), sin(yaw) * cos(elevation)).normalized()
	line.quaternion = Quaternion(Vector3.UP, line_direction)
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = visual_rng.randf_range(0.012, 0.024)
	line_mesh.bottom_radius = line_mesh.top_radius
	line_mesh.height = ability.hitbox_radius * visual_rng.randf_range(1.45, 2.15)
	line_mesh.radial_segments = 8
	line_mesh.rings = 1
	line_mesh.material = _vfx_material(Color(0.90, 0.97, 1.0, visual_rng.randf_range(0.72, 0.96)))
	line.mesh = line_mesh
	line.scale = Vector3(1.0, 0.012, 1.0)
	# Squared distribution: many lines arrive early, progressively fewer near 1.5 s.
	var distribution := float(line_index) / maxf(float(line_count - 1), 1.0)
	var appear_delay := pow(distribution, 2.0) * 1.42
	var grow_duration := 0.08
	var hold_duration := maxf(0.0, 1.5 - appear_delay - grow_duration)
	var line_tween := line.create_tween()
	line_tween.tween_interval(appear_delay)
	line_tween.tween_property(line, "scale:y", 1.0, grow_duration)
	line_tween.tween_interval(hold_duration)
	line_tween.tween_property(line, "scale", Vector3(0.06, 1.04, 0.06), 0.5)
	line_tween.parallel().tween_property(line, "transparency", 1.0, 0.5)
	line_tween.tween_callback(line.queue_free)


func _update_dimensional_visual_motion(delta: float, radius: float) -> void:
	if dimensional_visual_segment_remaining <= 0.0:
		dimensional_visual_from = dimensional_visual_offset
		var angle := visual_rng.randf_range(0.0, TAU)
		# Keep most destinations away from the centre so the model cuts across the
		# whole magic circle instead of oscillating around one axis.
		var distance := radius * 0.82 * pow(visual_rng.randf(), 0.34)
		dimensional_visual_to = Vector3(cos(angle), 0.0, sin(angle)) * distance
		dimensional_visual_segment_duration = visual_rng.randf_range(0.075, 0.14)
		dimensional_visual_segment_remaining = dimensional_visual_segment_duration
	dimensional_visual_segment_remaining = maxf(0.0, dimensional_visual_segment_remaining - delta)
	var progress := 1.0 - dimensional_visual_segment_remaining / maxf(dimensional_visual_segment_duration, 0.001)
	dimensional_visual_offset = dimensional_visual_from.lerp(dimensional_visual_to, progress)


func _spawn_afterimage(offset: Vector3) -> void:
	var ghost := Sprite3D.new()
	ghost.add_to_group("transient_combat_vfx")
	ghost.top_level = true
	ghost.texture = definition.sprite_texture
	ghost.pixel_size = definition.sprite_pixel_size
	ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ghost.modulate = Color(0.72, 0.84, 1.0, 0.45)
	get_parent().add_child(ghost)
	ghost.global_position = global_position + offset + Vector3.UP * definition.sprite_y
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.48)
	tween.tween_callback(ghost.queue_free)


func _spawn_shatter(radius: float) -> void:
	for index in range(10):
		var angle := TAU * float(index) / 10.0
		var shard := MeshInstance3D.new()
		shard.add_to_group("transient_combat_vfx")
		shard.top_level = true
		get_parent().add_child(shard)
		shard.global_position = global_position + Vector3.UP * 0.12
		shard.rotation.y = -angle
		var shard_mesh := BoxMesh.new()
		shard_mesh.size = Vector3(0.34 + 0.05 * float(index % 3), 0.035, 0.08)
		shard_mesh.material = _vfx_material(Color(0.78, 0.86, 1.0, 0.78))
		shard.mesh = shard_mesh
		var destination := shard.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.72
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", destination, 0.24)
		tween.parallel().tween_property(shard, "transparency", 1.0, 0.3)
		tween.tween_callback(shard.queue_free)


func _horizontal_crescent_mesh(color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 22
	for index in range(segments):
		var a0 := deg_to_rad(-72.0 + 144.0 * float(index) / segments)
		var a1 := deg_to_rad(-72.0 + 144.0 * float(index + 1) / segments)
		var inner0 := Vector3(sin(a0) * 0.90, 0.0, -cos(a0) * 0.42)
		var outer0 := Vector3(sin(a0), 0.0, -cos(a0) * 0.54)
		var inner1 := Vector3(sin(a1) * 0.90, 0.0, -cos(a1) * 0.42)
		var outer1 := Vector3(sin(a1), 0.0, -cos(a1) * 0.54)
		for vertex in [inner0, outer0, outer1, inner0, outer1, inner1]:
			surface.add_vertex(vertex)
	var mesh := surface.commit()
	var material := _vfx_material(color)
	mesh.surface_set_material(0, material)
	return mesh


func _vfx_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, true, true)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _is_control_locked() -> bool:
	return status_controller != null and status_controller.has_tag("stunned")


func _on_periodic_damage(amount: float, _source_actor_id: int, _effect_id: String) -> void:
	if is_defeated:
		return
	hp = maxf(0.0, hp - amount)
	flash_remaining = 0.13
	damaged.emit(self, amount)
	resource_changed.emit(self)
	if hp <= 0.0:
		_mark_defeated()


func _mark_defeated() -> void:
	if is_defeated:
		return
	if current_ability != null:
		_cancel_current_ability()
	roll_remaining = 0.0
	invulnerable_remaining = 0.0
	dash_remaining = 0.0
	nailoong_leap_remaining = 0.0
	nailoong_fire_emit_remaining = 0.0
	move_intent = Vector2.ZERO
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	is_defeated = true
	collision_layer = 0
	death_visual_elapsed = 0.0
	if definition.hero_id == "bear_grylls_jungler":
		# Always fall from the neutral full-body pose, even when the killing blow
		# interrupted a skill highlight frame.
		sprite.texture = base_sprite_texture
		sprite.position = Vector3(0.0, definition.sprite_y, sprite.position.z)
		sprite.scale = Vector3.ONE
	death_fall_side = -1.0 if visual_rng.randi_range(0, 1) == 0 else 1.0
	var facing_sign := -1.0 if facing.x < -0.05 else 1.0
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
	if hurt_debug_mesh != null:
		hurt_debug_mesh.visible = false
	if push_debug_mesh != null:
		push_debug_mesh.visible = false
	defeated.emit(self)


func _update_death_visual(delta: float) -> void:
	death_visual_elapsed += delta
	var progress := clampf(death_visual_elapsed / 0.52, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	sprite.visible = true
	sprite.position = death_body_start_position.lerp(Vector3(death_fall_side * 0.20, 0.38, death_body_start_position.z), eased)
	_set_visual_layer_angle(sprite, death_fall_side * PI * 0.5 * eased)
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
				_set_visual_layer_angle(layer_sprite, lerpf(start_angle, death_fall_side * 1.35, eased))
			"scabbard_back":
				layer_sprite.visible = true
				layer_sprite.position = start_position.lerp(Vector3(start_position.x - death_fall_side * 0.34, 0.12, start_position.z), eased)
				_set_visual_layer_angle(layer_sprite, lerpf(start_angle, death_fall_side * 0.12, eased))
			"katana_back":
				layer_sprite.visible = false
			"katana_action":
				layer_sprite.visible = true
				layer_sprite.position = start_position.lerp(Vector3(death_fall_side * 0.42, 0.82, start_position.z), eased)
				_set_visual_layer_angle(layer_sprite, lerpf(start_angle, death_sword_angle, eased))
			_:
				layer_sprite.visible = false


func _create_ground_marker() -> void:
	ground_marker = Node3D.new()
	ground_marker.name = "GroundRelationMarker"
	ground_marker.top_level = true
	var color := relation_color()
	var ring_instance := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = definition.body_radius * 1.22
	ring.outer_radius = definition.body_radius * 1.38
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
	surface.add_vertex(Vector3(0.0, 0.018, -definition.body_radius * 1.95))
	surface.add_vertex(Vector3(-0.16, 0.018, -definition.body_radius * 1.35))
	surface.add_vertex(Vector3(0.16, 0.018, -definition.body_radius * 1.35))
	var arrow_mesh := surface.commit()
	arrow_mesh.surface_set_material(0, _material(color, false, true))
	arrow_instance.mesh = arrow_mesh
	arrow_instance.scale = Vector3(1.45, 1.0, 1.45)
	arrow_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_marker.add_child(arrow_instance)
	add_child(ground_marker)


func _create_visual_layers() -> void:
	for layer in definition.visual_layers:
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
		add_child(layer_sprite)
		visual_layer_sprites[layer.layer_id] = layer_sprite


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


func _update_visual_layers() -> void:
	var action_id := current_ability.ability_id if current_ability != null else ""
	var facing_left := facing.x < -0.05
	if definition.hero_id == "sword_shield_dog":
		_update_sword_shield_layers(action_id, facing_left)
		return
	var action_sword_active := action_id in ["basic", "skill_q", "skill_w", "skill_e", "ultimate"]
	var phase_progress := _visual_phase_progress()
	for layer in definition.visual_layers:
		var layer_sprite := visual_layer_sprites.get(layer.layer_id) as Sprite3D
		if layer_sprite == null:
			continue
		var facing_sign := -1.0 if facing_left else 1.0
		var mirror_texture := facing_left if definition.sprite_faces_right else not facing_left
		layer_sprite.flip_h = mirror_texture
		layer_sprite.position.x = layer.offset.x * facing_sign
		layer_sprite.position.y = layer.offset.y
		layer_sprite.position.z = float(layer.render_priority) * 0.025
		# Keep the handle/pivot anchored when the source image is mirrored.
		layer_sprite.offset.x = -layer.texture_offset.x if mirror_texture else layer.texture_offset.x
		layer_sprite.offset.y = layer.texture_offset.y
		_set_visual_layer_angle(layer_sprite, layer.base_rotation * facing_sign)
		var visible := layer.visible_by_default
		if layer.layer_id == "katana_back":
			visible = not weapon_drawn and not action_sword_active
		elif layer.layer_id == "katana_action":
			visible = weapon_drawn or action_sword_active
		else:
			if not layer.show_during_actions.is_empty():
				visible = layer.show_during_actions.has(action_id)
			if layer.hide_during_actions.has(action_id):
				visible = false
		layer_sprite.visible = visible and not is_defeated
		layer_sprite.position.x += dimensional_visual_offset.x
		layer_sprite.position.z += dimensional_visual_offset.z
		layer_sprite.modulate = Color.WHITE
		if status_controller.has_tag("untargetable") and layer.layer_id != "katana_action":
			layer_sprite.modulate.a = 0.26
		if layer.remove_light_neutral_background and layer_sprite.material_override is ShaderMaterial:
			(layer_sprite.material_override as ShaderMaterial).set_shader_parameter("opacity", layer_sprite.modulate.a)
		if layer.layer_id == "katana_action" and layer_sprite.visible:
			layer_sprite.scale = Vector3.ONE
			var visual_time := action_elapsed
			if action_id in ["skill_w", "skill_e", "ultimate"]:
				layer_sprite.position.x -= facing_sign * ACTION_SWORD_BODY_INSET
			match action_id:
				"basic":
					if basic_combo_step == 0:
						if ability_phase == "startup":
							_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-1.50, -2.05, phase_progress))
							layer_sprite.position.x = facing_sign * lerpf(0.16, 0.48, phase_progress)
							layer_sprite.position.y = lerpf(0.94, 1.26, phase_progress)
						else:
							_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-2.05, 0.82, phase_progress if ability_phase == "active" else 1.0))
							layer_sprite.position.x += facing_sign * 0.25
					elif basic_combo_step == 1:
						_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(0.92, -1.18, phase_progress if ability_phase == "active" else 0.0))
						layer_sprite.position.x += facing_sign * 0.32
					else:
						_set_visual_layer_angle(layer_sprite, facing_sign * 0.02)
						layer_sprite.position.x += facing_sign * lerpf(0.20, 0.86, phase_progress if ability_phase == "active" else 0.15)
						layer_sprite.scale.x = lerpf(0.88, 1.22, phase_progress if ability_phase == "active" else 0.0)
				"skill_q":
					_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(0.62, -1.28, phase_progress))
					layer_sprite.position.x += facing_sign * lerpf(0.18, 0.62, phase_progress)
					layer_sprite.position.y += lerpf(-0.06, 0.38, phase_progress)
				"skill_w":
					_set_visual_layer_angle(layer_sprite, facing_sign * sin(visual_time * 34.0) * 0.34)
					layer_sprite.position.x += facing_sign * 0.58
					layer_sprite.scale.x = 0.72 + absf(sin(visual_time * 34.0)) * 0.78
				"skill_e":
					_set_visual_layer_angle(layer_sprite, facing_sign * 0.02)
					layer_sprite.position.x += facing_sign * 0.86
					layer_sprite.scale.x = 1.20
				"ultimate":
					if ability_phase == "startup":
						_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-1.50, -2.02, phase_progress))
						layer_sprite.position.y += lerpf(0.0, 0.38, phase_progress)
					elif ability_phase == "active":
						_set_visual_layer_angle(layer_sprite, facing_sign * sin(visual_time * 38.0) * 0.42)
						layer_sprite.position.x += facing_sign * sin(visual_time * 27.0) * 0.92
						layer_sprite.scale.x = 1.30
				_:
					_set_visual_layer_angle(layer_sprite, facing_sign * -0.34)
					layer_sprite.position.x += facing_sign * 0.18


func _update_sword_shield_layers(action_id: String, facing_left: bool) -> void:
	var facing_sign := -1.0 if facing_left else 1.0
	var mirror_texture := facing_left if definition.sprite_faces_right else not facing_left
	var progress := _visual_phase_progress()
	for layer in definition.visual_layers:
		var layer_sprite := visual_layer_sprites.get(layer.layer_id) as Sprite3D
		if layer_sprite == null:
			continue
		layer_sprite.flip_h = mirror_texture
		layer_sprite.offset.x = -layer.texture_offset.x if mirror_texture else layer.texture_offset.x
		layer_sprite.offset.y = layer.texture_offset.y
		layer_sprite.position = Vector3(layer.offset.x * facing_sign, layer.offset.y, float(layer.render_priority) * 0.025)
		layer_sprite.scale = Vector3.ONE
		layer_sprite.modulate = Color.WHITE
		_set_visual_layer_angle(layer_sprite, layer.base_rotation * facing_sign)
		layer_sprite.visible = not transformed and not is_defeated
		if not layer_sprite.visible:
			continue
		if action_id == "ultimate" and ability_phase == "startup":
			layer_sprite.position.x = lerpf(layer_sprite.position.x, 0.0, progress)
			layer_sprite.position.y = lerpf(layer_sprite.position.y, 1.48, progress)
			layer_sprite.scale = Vector3.ONE * lerpf(1.0, 0.08, progress)
			_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(layer.base_rotation, 2.4, progress))
		elif layer.layer_id == "shield_dog_sword":
			match action_id:
				"basic":
					layer_sprite.position.x += facing_sign * 0.08
					layer_sprite.position.y += 0.08
					if ability_phase == "startup":
						_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(layer.base_rotation, 1.18, progress))
					elif ability_phase == "active":
						_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(1.18, -0.58, progress))
					else:
						var return_progress := clampf((progress - 0.55) / 0.45, 0.0, 1.0)
						_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(-0.58, layer.base_rotation, return_progress))
				"skill_w":
					layer_sprite.position.x += facing_sign * 0.06
					if ability_phase == "startup":
						layer_sprite.scale = Vector3(lerpf(1.0, 2.25, progress), lerpf(1.0, 1.28, progress), 1.0)
						_set_visual_layer_angle(layer_sprite, facing_sign * layer.base_rotation)
					elif ability_phase == "active":
						var chop_progress := clampf(progress / 0.72, 0.0, 1.0)
						layer_sprite.scale = Vector3(2.25, 1.28, 1.0)
						_set_visual_layer_angle(layer_sprite, facing_sign * lerpf(1.52, -0.62, chop_progress))
					else:
						layer_sprite.scale = Vector3.ONE
						_set_visual_layer_angle(layer_sprite, facing_sign * layer.base_rotation)
				_:
					pass
		else:
			match action_id:
				"skill_q":
					layer_sprite.position.x = facing_sign * 0.58
					layer_sprite.position.y = 0.88
					layer_sprite.scale = Vector3.ONE * 1.16
					_set_visual_layer_angle(layer_sprite, facing_sign * -0.06)
				"skill_e":
					layer_sprite.position.y = 0.86
					if ability_phase == "startup":
						layer_sprite.position.x = facing_sign * lerpf(absf(layer.offset.x), 0.50, progress)
						layer_sprite.scale = Vector3.ONE * lerpf(1.0, 1.30, progress)
					elif ability_phase == "active":
						var push_progress := clampf(progress / 0.48, 0.0, 1.0)
						layer_sprite.position.x = facing_sign * lerpf(0.50, 0.78, push_progress)
						layer_sprite.scale = Vector3.ONE * 1.30
					else:
						var return_progress := clampf((progress - 0.45) / 0.55, 0.0, 1.0)
						layer_sprite.position.x = facing_sign * lerpf(0.78, absf(layer.offset.x), return_progress)
						layer_sprite.scale = Vector3.ONE * lerpf(1.30, 1.0, return_progress)
				_:
					pass


func _visual_phase_progress() -> float:
	if current_ability == null:
		return 0.0
	var duration := current_ability.startup
	if ability_phase == "active":
		duration = current_ability.active
	elif ability_phase == "recovery":
		duration = current_ability.recovery
	return clampf(1.0 - phase_remaining / maxf(duration, 0.001), 0.0, 1.0)


func _set_visual_layer_angle(layer_sprite: Sprite3D, angle: float) -> void:
	layer_sprite.set_meta("visual_angle", angle)
	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		layer_sprite.rotation.z = angle
		return
	# Copy only camera orientation. Looking at the camera position changes yaw as the
	# actor crosses the screen and makes a 2D cutout visibly twist in 3D space.
	var visual_scale := layer_sprite.scale
	var camera_basis := active_camera.global_basis.orthonormalized()
	# Apply scale in sprite-local axes after the animation rotation. This keeps a
	# vertical sword's X scale aligned with blade length instead of screen width.
	layer_sprite.global_basis = camera_basis * Basis(Vector3.BACK, angle) * Basis.from_scale(visual_scale)


func relation_color() -> Color:
	match relation:
		Relation.SELF:
			return Color("54db72")
		Relation.ALLY:
			return Color("58a8ff")
		_:
			return Color("ef5f5f")


func _capsule_debug_mesh(radius: float, capsule_height: float, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = capsule_height
	mesh.radial_segments = 20
	mesh.rings = 6
	mesh.material = _material(color, true, true)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _material(color: Color, transparent := false, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = transparent
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
