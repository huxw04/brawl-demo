class_name CombatActor
extends CharacterBody3D

signal resource_changed(actor: CombatActor)
signal action_started(actor: CombatActor, action_id: String)
signal action_finished(actor: CombatActor, action_id: String)
signal damaged(actor: CombatActor, amount: float)
signal damage_received(actor: CombatActor, source_actor_id: int, amount: float)
signal defeated(actor: CombatActor)

const AttackHitboxScript = preload("res://src/combat/attack_hitbox.gd")
const CombatEntityFactoryScript = preload("res://src/combat/runtime/combat_entity_factory.gd")
const ActorPresentationScript = preload("res://src/presentation/actor_presentation.gd")
const CombatResourceRuntimeScript = preload("res://src/combat/runtime/combat_resource_runtime.gd")
const AbilityTimelineRuntimeScript = preload("res://src/combat/runtime/ability_timeline_runtime.gd")
const HeroRuntimeScript = preload("res://src/combat/hero_runtime/hero_runtime.gd")
const BearHeroRuntimeScript = preload("res://src/combat/hero_runtime/bear_hero_runtime.gd")
const CheemsHeroRuntimeScript = preload("res://src/combat/hero_runtime/cheems_hero_runtime.gd")
const NailoongHeroRuntimeScript = preload("res://src/combat/hero_runtime/nailoong_hero_runtime.gd")
const SwordShieldHeroRuntimeScript = preload("res://src/combat/hero_runtime/sword_shield_hero_runtime.gd")
const ChuYingHeroRuntimeScript = preload("res://src/combat/hero_runtime/chu_ying_hero_runtime.gd")
const HERO_RUNTIME_SCRIPTS := {
	"bear_grylls_jungler": BearHeroRuntimeScript,
	"cheems_samurai": CheemsHeroRuntimeScript,
	"nailoong": NailoongHeroRuntimeScript,
	"sword_shield_dog": SwordShieldHeroRuntimeScript,
	"chu_ying": ChuYingHeroRuntimeScript,
}

static var debug_shapes := false
static var next_attack_id := 1

enum Relation { SELF, ALLY, ENEMY }

var definition: HeroDefinition
var battle_id := 0
var entity_id := 0
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
var respawn_remaining := 0.0
var spawn_protection_remaining := 0.0
var authority_replica_mode := false
var replica_position_target := Vector3.ZERO
var replica_velocity := Vector3.ZERO
var replica_snapshot_age := 0.0
var replica_has_snapshot := false
var basic_combo_step := 0
var weapon_drawn := false
var sheathe_remaining := 0.0
var current_attack_damage_multiplier := 1.0
var action_elapsed := 0.0
var visual_rng := RandomNumberGenerator.new()
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
var actor_presentation: ActorPresentation
var resource_runtime: CombatResourceRuntime
var ability_runtime: AbilityTimelineRuntime
var hero_runtime: HeroRuntime

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
	actor_presentation = ActorPresentationScript.new() as ActorPresentation
	actor_presentation.name = "ActorPresentation"
	add_child(actor_presentation)
	resource_runtime = CombatResourceRuntimeScript.new() as CombatResourceRuntime
	resource_runtime.setup(self)
	ability_runtime = AbilityTimelineRuntimeScript.new() as AbilityTimelineRuntime
	ability_runtime.setup(self)
	var runtime_script = HERO_RUNTIME_SCRIPTS.get(definition.hero_id, HeroRuntimeScript)
	hero_runtime = runtime_script.new() as HeroRuntime
	hero_runtime.setup(self)
	hero_runtime.initialize()
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
	actor_presentation.setup(self)
	sprite = actor_presentation.sprite
	shadow_mesh = actor_presentation.shadow_mesh
	name_label = actor_presentation.name_label
	hp_label = actor_presentation.hp_label
	energy_label = actor_presentation.energy_label
	status_visual = actor_presentation.status_visual
	visual_layer_sprites = actor_presentation.visual_layer_sprites
	ground_marker = actor_presentation.ground_marker

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
	ability = hero_runtime.select_ability(id, ability)
	if not hero_runtime.prepare_ability(id, ability):
		return false
	var bypass := ignore_requirements or ignore_ability_requirements
	if not bypass:
		if not hero_runtime.has_special_resource(id):
			return false
		if not resource_runtime.can_pay(id, ability):
			return false
		resource_runtime.pay(ability)
	hero_runtime.commit_ability(id, ability, bypass)
	ability_runtime.begin(ability, id)
	return true


func can_select_ability(id: String) -> bool:
	var ability := ability_by_id(id)
	if ability == null or ability.disabled or is_defeated or _is_control_locked() or hurt_remaining > 0.0 or roll_remaining > 0.0:
		return false
	# Nailoong's rolling action may be cancelled by another available skill.
	# Other active actions must finish before a new targeting mode can be armed.
	if current_ability != null and not current_ability.cancelable_by_ability:
		return false
	if ignore_ability_requirements:
		return true
	if not resource_runtime.can_pay(id, ability):
		return false
	if not hero_runtime.has_special_resource(id):
		return false
	return true


func ability_by_id(id: String) -> AbilityDefinition:
	var fallback := definition.ability_by_id(id)
	return hero_runtime.resolve_ability(id, fallback) if hero_runtime != null else fallback


func release_held_ability(id: String) -> void:
	if current_ability == null or current_ability.ability_id != id or not current_ability.hold_to_channel:
		return
	held_release_requested = true
	_try_finish_held_ability()


func cancel_nailoong_roll_for_command() -> void:
	hero_runtime.cancel_special_for_command()


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_update_timers(delta)
	_update_action(delta)
	_update_motion(delta)
	_update_visual(delta)


func _process(delta: float) -> void:
	if authority_replica_mode:
		_advance_replica_position(delta)
		_update_visual(delta)


func set_authority_replica_mode(enabled: bool) -> void:
	authority_replica_mode = enabled
	set_physics_process(not enabled)
	set_process(enabled)
	if enabled:
		collision_layer = 0
		velocity = Vector3.ZERO
		knockback_velocity = Vector3.ZERO
		move_intent = Vector2.ZERO
		replica_position_target = global_position
		replica_velocity = Vector3.ZERO
		replica_snapshot_age = 0.0
		replica_has_snapshot = false


func _advance_replica_position(delta: float) -> void:
	if not replica_has_snapshot:
		return
	replica_snapshot_age += delta
	var extrapolation := minf(replica_snapshot_age, 0.12)
	var destination := replica_position_target + replica_velocity * extrapolation
	if global_position.distance_to(destination) > 2.0:
		global_position = destination
		return
	var smoothing := 1.0 - exp(-22.0 * delta)
	global_position = global_position.lerp(destination, smoothing)


func is_visually_grounded() -> bool:
	return height <= 0.08 if authority_replica_mode else is_on_floor()


func _update_timers(delta: float) -> void:
	status_controller.advance(delta)
	_update_pending_statuses(delta)
	_update_pending_damage_events(delta)
	resource_runtime.advance_timers(delta)
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	spawn_protection_remaining = maxf(0.0, spawn_protection_remaining - delta)
	hurt_remaining = maxf(0.0, hurt_remaining - delta)
	flash_remaining = maxf(0.0, flash_remaining - delta)
	hero_runtime.advance(delta)
	resource_runtime.regenerate_stamina(delta)


func _update_action(delta: float) -> void:
	ability_runtime.advance(delta)


func _try_finish_held_ability() -> void:
	ability_runtime.finish_held_if_ready()


func _update_continuous_ability_vfx(delta: float) -> void:
	if current_ability == null or ability_phase != "active":
		return
	hero_runtime.update_continuous_ability(delta)


func _activate_ability(ability: AbilityDefinition) -> void:
	var attack_id := next_attack_id
	next_attack_id += 1
	if ability.breaks_stealth and status_controller.has_tag("stealth"):
		status_controller.remove("bear_stealth")
	if hero_runtime.activate_ability(ability, attack_id):
		return
	if not hero_runtime.before_shared_activation(ability, attack_id):
		return
	if ability.self_untargetable_duration > 0.0:
		apply_status(CombatStatuses.untargetable(ability.self_untargetable_duration), battle_id)
	if ability.dash_distance > 0.0:
		_perform_dash(ability)
	if ability.movement_impulse > 0.0:
		knockback_velocity += facing * ability.movement_impulse
	if ability.is_projectile():
		CombatEntityFactoryScript.spawn_projectile(
			match_authority(), get_parent(), self, ability, facing, attack_id,
			global_position + facing * 0.62 + Vector3.UP * ability.projectile_height
		)
	elif ability.spawns_attack:
		var hitbox := AttackHitboxScript.new() as AttackHitbox
		add_child(hitbox)
		hitbox.configure(self, ability, attack_id)
	if ability.delayed_damage > 0.0 and ability.delayed_delay > 0.0 and ability.delayed_radius > 0.0:
		var delayed_center := global_position + facing * ability.delayed_center_distance
		CombatEntityFactoryScript.spawn_delayed_attack(match_authority(), get_parent(), self, ability, attack_id, delayed_center)
	_spawn_ability_vfx(ability)


func match_authority() -> MatchAuthority:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("match_authority") as MatchAuthority


func authoritative_actor_state() -> Dictionary:
	return {
		"actor_id": battle_id,
		"hero_id": definition.hero_id if definition != null else "",
		"team": team,
		"position": _vector_packet(global_position),
	}


func authoritative_snapshot() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_kind": "actor",
		"state": network_state_packet(),
	}


func _vector_packet(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]



func _apply_startup_effects(ability: AbilityDefinition) -> void:
	if ability.self_control_immune_duration > 0.0:
		apply_status(CombatStatuses.control_immune(ability.self_control_immune_duration), battle_id)
	hero_runtime.before_startup_effects(ability)
	if ability.startup_slow_duration <= 0.0:
		hero_runtime.after_startup_effects(ability)
		return
	if ability.startup_slow_ratio < 1.0:
		for value in get_tree().get_nodes_in_group("combat_actors"):
			if value is CombatActor:
				var target := value as CombatActor
				if target != self and target.team != team and not target.is_defeated and global_position.distance_squared_to(target.global_position) <= ability.hitbox_radius * ability.hitbox_radius:
					target.apply_status(CombatStatuses.slow(ability.startup_slow_duration, ability.startup_slow_ratio), battle_id)
	hero_runtime.after_startup_effects(ability)


func _update_motion(delta: float) -> void:
	if hero_runtime.update_pre_motion(delta):
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
	if hero_runtime.update_ground_special_motion(delta):
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
		var movement_speed := definition.move_speed * hero_runtime.movement_speed_multiplier() * status_controller.multiplier("move_speed")
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
	if not can_receive_attack():
		return false
	if hero_runtime.blocks_attack_from(source):
		hero_runtime.on_attack_blocked(source)
		return false
	var dealt_damage: float = ability.damage if damage_override < 0.0 else damage_override
	if source != null:
		dealt_damage = source.modify_outgoing_damage(self, ability, dealt_damage)
	if current_ability != null and ability_phase == "active":
		dealt_damage *= current_ability.damage_taken_multiplier_during_cast
	var hp_before := hp
	hp = maxf(0.0, hp - dealt_damage)
	var actual_damage := hp_before - hp
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
	damage_received.emit(self, source.battle_id if source != null else 0, actual_damage)
	resource_changed.emit(self)
	if hp <= 0.0:
		_mark_defeated()
		if source != null:
			source.on_killed_actor(self, ability)
	return true


func can_receive_attack() -> bool:
	return not is_defeated and invulnerable_remaining <= 0.0 and spawn_protection_remaining <= 0.0 and is_targetable()


func _cancel_current_ability() -> void:
	ability_runtime.cancel_current()


func spend_stamina(amount: float) -> void:
	resource_runtime.spend_stamina(amount)


func gain_energy(amount: float) -> void:
	resource_runtime.gain_energy(amount)


func reset_runtime(at_position: Vector3) -> void:
	global_position = at_position
	velocity = Vector3.ZERO
	hp = definition.max_hp
	resource_runtime.reset()
	ability_runtime.reset()
	roll_remaining = 0.0
	invulnerable_remaining = 0.0
	hurt_remaining = 0.0
	dash_remaining = 0.0
	dash_duration = 0.0
	dash_phasing = false
	knockback_velocity = Vector3.ZERO
	is_defeated = false
	respawn_remaining = 0.0
	spawn_protection_remaining = 0.0
	collision_layer = 4
	actor_presentation.reset_visual()
	_set_visual_layer_angle(sprite, 0.0)
	status_controller.clear()
	pending_statuses.clear()
	pending_damage_events.clear()
	pending_ability_target = Vector3.ZERO
	hero_runtime.reset()
	for child in get_children():
		if child is AttackHitbox:
			child.queue_free()
	resource_changed.emit(self)


func cooldown_ratio(id: String) -> float:
	return resource_runtime.cooldown_ratio(id)


func status_text() -> String:
	if is_defeated:
		return "%.1f 秒后复活" % respawn_remaining if respawn_remaining > 0.0 else "DEFEATED"
	if spawn_protection_remaining > 0.0:
		return "复活保护 %.1f" % spawn_protection_remaining
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
	var component_snapshot := hero_runtime.runtime_snapshot()
	if not component_snapshot.is_empty():
		return component_snapshot
	return {}


func network_state_packet() -> Dictionary:
	var current_id := ""
	if current_ability != null:
		current_id = current_ability.ability_id
	return {
		"actor_id": battle_id,
		"position": [global_position.x, global_position.y, global_position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"facing": [facing.x, facing.z],
		"knockback": [knockback_velocity.x, knockback_velocity.y, knockback_velocity.z],
		"hp": hp,
		"stamina": stamina,
		"energy": energy,
		"cooldowns": cooldowns.duplicate(true),
		"stamina_regen_block": stamina_regen_block,
		"roll_remaining": roll_remaining,
		"invulnerable_remaining": invulnerable_remaining,
		"hurt_remaining": hurt_remaining,
		"defeated": is_defeated,
		"respawn_remaining": respawn_remaining,
		"spawn_protection_remaining": spawn_protection_remaining,
		"current_ability": current_id,
		"ability_phase": ability_phase,
		"phase_remaining": phase_remaining,
		"transformed": transformed,
		"transformed_remaining": transformed_remaining,
		"chu_ying_q_charges": chu_ying_q_charges,
		"chu_ying_q_recharge": chu_ying_q_recharge_remaining,
		"statuses": status_controller.network_snapshot(),
		"hero_runtime": hero_runtime.runtime_snapshot(),
	}


func apply_authoritative_network_state(packet: Dictionary) -> void:
	var position: Array = packet.get("position", []) as Array
	if position.size() >= 3:
		var authoritative_position := Vector3(float(position[0]), float(position[1]), float(position[2]))
		replica_position_target = authoritative_position
		replica_snapshot_age = 0.0
		if not replica_has_snapshot or global_position.distance_to(authoritative_position) > 2.0:
			global_position = authoritative_position
		replica_has_snapshot = true
	var authoritative_defeated := bool(packet.get("defeated", false))
	if is_defeated and not authoritative_defeated:
		reset_runtime(global_position)
	hp = clampf(float(packet.get("hp", hp)), 0.0, definition.max_hp)
	stamina = clampf(float(packet.get("stamina", stamina)), 0.0, definition.max_stamina)
	energy = clampf(float(packet.get("energy", energy)), 0.0, definition.max_energy)
	stamina_regen_block = maxf(0.0, float(packet.get("stamina_regen_block", stamina_regen_block)))
	roll_remaining = maxf(0.0, float(packet.get("roll_remaining", roll_remaining)))
	invulnerable_remaining = maxf(0.0, float(packet.get("invulnerable_remaining", invulnerable_remaining)))
	hurt_remaining = maxf(0.0, float(packet.get("hurt_remaining", hurt_remaining)))
	respawn_remaining = maxf(0.0, float(packet.get("respawn_remaining", respawn_remaining)))
	spawn_protection_remaining = maxf(0.0, float(packet.get("spawn_protection_remaining", spawn_protection_remaining)))
	var authoritative_transformed := bool(packet.get("transformed", transformed))
	hero_runtime.apply_transformed_state(authoritative_transformed)
	transformed_remaining = maxf(0.0, float(packet.get("transformed_remaining", transformed_remaining)))
	var hero_runtime_packet = packet.get("hero_runtime", {})
	if hero_runtime_packet is Dictionary:
		hero_runtime.apply_runtime_snapshot(hero_runtime_packet as Dictionary)
	var cooldown_packet = packet.get("cooldowns", {})
	if cooldown_packet is Dictionary:
		cooldowns.clear()
		for id in (cooldown_packet as Dictionary).keys():
			cooldowns[str(id)] = maxf(0.0, float((cooldown_packet as Dictionary)[id]))
	chu_ying_q_charges = maxi(0, int(packet.get("chu_ying_q_charges", chu_ying_q_charges)))
	chu_ying_q_recharge_remaining = maxf(0.0, float(packet.get("chu_ying_q_recharge", chu_ying_q_recharge_remaining)))
	var velocity_packet: Array = packet.get("velocity", []) as Array
	if velocity_packet.size() >= 3:
		velocity = Vector3(float(velocity_packet[0]), float(velocity_packet[1]), float(velocity_packet[2]))
		replica_velocity = velocity
		move_intent = Vector2(velocity.x, velocity.z).normalized() if Vector2(velocity.x, velocity.z).length_squared() > 0.01 else Vector2.ZERO
	var knockback_packet: Array = packet.get("knockback", []) as Array
	if knockback_packet.size() >= 3:
		knockback_velocity = Vector3(float(knockback_packet[0]), float(knockback_packet[1]), float(knockback_packet[2]))
	var facing_packet: Array = packet.get("facing", []) as Array
	if facing_packet.size() >= 2:
		var authoritative_facing := Vector3(float(facing_packet[0]), 0.0, float(facing_packet[1]))
		if authoritative_facing.length_squared() > 0.001:
			facing = authoritative_facing.normalized()
	var status_packet = packet.get("statuses", [])
	if status_packet is Array:
		status_controller.restore_network_snapshot(status_packet as Array)
	var action_id := str(packet.get("current_ability", ""))
	current_ability = ability_by_id(action_id) if not action_id.is_empty() else null
	ability_phase = str(packet.get("ability_phase", "")) if current_ability != null else ""
	phase_remaining = maxf(0.0, float(packet.get("phase_remaining", 0.0))) if current_ability != null else 0.0
	if current_ability != null:
		var phase_duration := current_ability.startup
		if ability_phase == "active":
			phase_duration = current_ability.active
		elif ability_phase == "recovery":
			phase_duration = current_ability.recovery
		action_elapsed = maxf(0.0, phase_duration - phase_remaining)
	else:
		action_elapsed = 0.0
	if authoritative_defeated and not is_defeated:
		_mark_defeated()
	if authority_replica_mode:
		collision_layer = 0
	resource_changed.emit(self)


func refresh_debug_visibility() -> void:
	if hurt_debug_mesh != null:
		hurt_debug_mesh.visible = debug_shapes
	if push_debug_mesh != null:
		push_debug_mesh.visible = debug_shapes


func _update_visual(delta: float) -> void:
	actor_presentation.update(delta)


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
	source.hero_runtime.on_delayed_damage_queued(self, ability)


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
			source.hero_runtime.on_delayed_damage_resolved(self, ability)


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


func begin_grapple_pull(endpoint: Vector3) -> void:
	hero_runtime.begin_grapple_pull(endpoint)


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


func on_ability_hit(ability: AbilityDefinition, dealt_damage := 0.0) -> void:
	gain_energy(ability.energy_on_hit)
	var healing := ability.healing_on_hit + dealt_damage * ability.lifesteal_ratio
	if healing > 0.0 and not is_defeated:
		hp = minf(definition.max_hp, hp + healing)
		resource_changed.emit(self)
	if ability.refresh_cooldown_on_hit:
		cooldowns[ability.ability_id] = 0.0


func modify_outgoing_damage(target: CombatActor, ability: AbilityDefinition, base_damage: float) -> float:
	return hero_runtime.modify_outgoing_damage(target, ability, base_damage)


func on_killed_actor(_target: CombatActor, ability: AbilityDefinition) -> void:
	hero_runtime.on_killed_actor(_target, ability)


func on_hitbox_pulse(ability: AbilityDefinition, pulse_index: int) -> void:
	hero_runtime.on_hitbox_pulse(ability, pulse_index)


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
	if actor_presentation.is_one_shot_ability_vfx(ability) and hero_runtime.emit_hero_effect("ability_vfx", {
		"ability_id": ability.ability_id,
		"ability_vfx_id": ability.vfx_id,
	}):
		return
	actor_presentation.spawn_ability_vfx(ability)


func _is_control_locked() -> bool:
	return status_controller != null and status_controller.has_tag("stunned")


func _on_periodic_damage(amount: float, source_actor_id: int, _effect_id: String) -> void:
	if is_defeated:
		return
	var hp_before := hp
	hp = maxf(0.0, hp - amount)
	var actual_damage := hp_before - hp
	flash_remaining = 0.13
	damaged.emit(self, amount)
	damage_received.emit(self, source_actor_id, actual_damage)
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
	spawn_protection_remaining = 0.0
	dash_remaining = 0.0
	hero_runtime.on_defeated()
	move_intent = Vector2.ZERO
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	is_defeated = true
	collision_layer = 0
	actor_presentation.begin_death()
	if hurt_debug_mesh != null:
		hurt_debug_mesh.visible = false
	if push_debug_mesh != null:
		push_debug_mesh.visible = false
	defeated.emit(self)


func _set_visual_layer_angle(layer_sprite: Sprite3D, angle: float) -> void:
	actor_presentation.set_visual_layer_angle(layer_sprite, angle)


func relation_color() -> Color:
	return actor_presentation.relation_color()


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
