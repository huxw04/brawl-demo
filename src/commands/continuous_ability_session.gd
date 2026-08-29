class_name ContinuousAbilitySession
extends RefCounted

enum State { IDLE, HOLDING, RELEASE_PENDING }

var actor: CombatActor
var state := State.IDLE
var ability_id := ""


func setup(p_actor: CombatActor) -> void:
	actor = p_actor
	reset()


func begin(id: String) -> bool:
	refresh()
	if actor == null or state != State.IDLE:
		return false
	var ability := actor.ability_by_id(id)
	if ability == null or not ability.hold_to_channel:
		return false
	if not actor.try_ability(id):
		return false
	ability_id = id
	state = State.HOLDING
	return true


func end(id: String) -> bool:
	refresh()
	if actor == null or state != State.HOLDING or id != ability_id:
		return false
	actor.release_held_ability(id)
	state = State.RELEASE_PENDING
	refresh()
	return true


func release_for_movement() -> bool:
	refresh()
	if actor == null or state != State.HOLDING or actor.current_ability == null:
		return false
	if not actor.current_ability.cancelable_by_movement:
		return false
	actor.release_held_ability(ability_id)
	state = State.RELEASE_PENDING
	refresh()
	return true


func cancel_special() -> bool:
	refresh()
	if actor == null or actor.current_ability == null or actor.current_ability.vfx_id != "nailoong_roll":
		return false
	actor.cancel_nailoong_roll_for_command()
	refresh()
	return true


func force_cleanup() -> bool:
	refresh()
	if actor == null or actor.current_ability == null:
		reset()
		return false
	var ability := actor.current_ability
	if not ability.hold_to_channel and ability.vfx_id != "nailoong_roll":
		reset()
		return false
	actor._cancel_current_ability()
	reset()
	return true


func refresh() -> void:
	if state == State.IDLE:
		return
	if actor == null or actor.current_ability == null or actor.current_ability.ability_id != ability_id or not actor.current_ability.hold_to_channel:
		reset()


func reset() -> void:
	state = State.IDLE
	ability_id = ""
