class_name AbilityTimelineRuntime
extends RefCounted

## Owns transitions between startup, active, recovery and idle while the public
## state remains on CombatActor for snapshot compatibility. It never advances by
## itself; CombatActor or a future MatchAuthority must call advance().

var actor: CombatActor


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func begin(ability: AbilityDefinition, ability_id: String) -> void:
	actor.current_ability = ability
	actor.held_release_requested = false
	actor.ability_phase = "startup"
	actor.phase_remaining = ability.startup
	actor.action_elapsed = 0.0
	actor.actor_presentation.begin_action()
	if not ability.hold_to_channel and not ability.cooldown_on_finish and not ability.cooldown_on_form_end:
		actor.cooldowns[ability_id] = ability.cooldown
	actor._apply_startup_effects(ability)
	actor.action_started.emit(actor, ability_id)
	actor.resource_changed.emit(actor)


func advance(delta: float) -> void:
	if actor.roll_remaining > 0.0:
		actor.roll_remaining = maxf(0.0, actor.roll_remaining - delta)
		if actor.roll_remaining <= 0.0:
			actor.action_finished.emit(actor, "roll")
	if actor.current_ability == null:
		return
	actor.action_elapsed += delta
	actor._update_continuous_ability_vfx(delta)
	if actor.ability_phase == "active" and actor.current_ability.hold_to_channel:
		finish_held_if_ready()
		return
	actor.phase_remaining -= delta
	if actor.phase_remaining > 0.0:
		return
	if actor.ability_phase == "startup":
		actor.ability_phase = "active"
		actor.phase_remaining = actor.current_ability.active
		actor._activate_ability(actor.current_ability)
	elif actor.ability_phase == "active":
		actor.ability_phase = "recovery"
		actor.phase_remaining = actor.current_ability.recovery
	else:
		finish_current()


func finish_held_if_ready() -> void:
	if actor.current_ability == null or not actor.current_ability.hold_to_channel:
		return
	var auto_finished := actor.current_ability.maximum_hold_duration > 0.0 and actor.action_elapsed >= actor.current_ability.startup + actor.current_ability.maximum_hold_duration
	if not actor.held_release_requested and not auto_finished:
		return
	if not auto_finished and actor.action_elapsed < actor.current_ability.startup + actor.current_ability.minimum_hold_duration:
		return
	var finished_id := actor.current_ability.ability_id
	var cooldown := actor.current_ability.cooldown
	actor.current_ability = null
	actor.ability_phase = "idle"
	actor.phase_remaining = 0.0
	actor.held_release_requested = false
	actor.cooldowns[finished_id] = cooldown
	actor.action_finished.emit(actor, finished_id)
	actor.resource_changed.emit(actor)


func finish_current() -> void:
	if actor.current_ability == null:
		return
	var finished_id := actor.current_ability.ability_id
	var finished_ability := actor.current_ability
	if finished_id == "basic":
		actor.hero_runtime.on_basic_finished(actor.current_ability.cooldown)
	actor.current_ability = null
	actor.ability_phase = "idle"
	actor.phase_remaining = 0.0
	actor.action_finished.emit(actor, finished_id)
	if finished_ability.cooldown_on_finish:
		actor.cooldowns[finished_id] = finished_ability.cooldown


func cancel_current() -> void:
	if actor.current_ability == null:
		return
	var interrupted_id := actor.current_ability.ability_id
	var interrupted_ability := actor.current_ability
	if interrupted_id == "basic":
		actor.hero_runtime.on_basic_finished(actor.current_ability.cooldown)
	actor.current_ability = null
	actor.ability_phase = "idle"
	actor.phase_remaining = 0.0
	for child in actor.get_children():
		if child is AttackHitbox:
			child.queue_free()
	actor.action_finished.emit(actor, interrupted_id)
	if interrupted_ability.hold_to_channel or interrupted_ability.cooldown_on_finish:
		actor.cooldowns[interrupted_id] = interrupted_ability.cooldown


func reset() -> void:
	actor.current_ability = null
	actor.ability_phase = "idle"
	actor.phase_remaining = 0.0
	actor.action_elapsed = 0.0
	actor.held_release_requested = false
