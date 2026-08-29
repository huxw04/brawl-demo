class_name SwordShieldHeroRuntime
extends HeroRuntime

## Sword-and-shield dog's authoritative form and guard rules. The public form
## fields remain on CombatActor so the current network packet stays compatible.


func resolve_ability(ability_id: String, fallback: AbilityDefinition) -> AbilityDefinition:
	if not actor.transformed:
		return fallback
	var transformed_ability := actor.definition.transformed_ability_by_id(ability_id)
	if transformed_ability != null:
		return transformed_ability
	if ability_id in ["skill_q", "skill_w", "skill_e", "ultimate"]:
		return null
	return fallback


func activate_ability(ability: AbilityDefinition, _attack_id: int) -> bool:
	if ability.vfx_id != "sword_shield_transform":
		return false
	_enter_transformed_form()
	return true


func blocks_attack_from(source: CombatActor) -> bool:
	if actor.current_ability == null or not actor.current_ability.blocks_front_damage or actor.ability_phase != "active" or source == null:
		return false
	var to_source := source.global_position - actor.global_position
	to_source.y = 0.0
	if to_source.length_squared() <= 0.001:
		return true
	var threshold := cos(deg_to_rad(actor.current_ability.front_block_degrees * 0.5))
	return actor.facing.dot(to_source.normalized()) >= threshold


func on_attack_blocked(_source: CombatActor) -> void:
	if emit_hero_effect("sword_shield_block"):
		return
	var vfx := actor.actor_presentation.hero_vfx as SwordShieldVfx
	if vfx != null:
		vfx.spawn_block_flash()


func movement_speed_multiplier() -> float:
	return actor.definition.transformed_move_speed_multiplier if actor.transformed else 1.0


func apply_transformed_state(active: bool) -> void:
	if active == actor.transformed:
		return
	if active:
		_enter_transformed_form()
	else:
		_exit_transformed_form(true)


func advance(delta: float) -> void:
	if not actor.transformed:
		return
	actor.transformed_remaining = maxf(0.0, actor.transformed_remaining - delta)
	if actor.transformed_remaining <= 0.0:
		_exit_transformed_form(true)


func reset() -> void:
	actor.transformed = false
	actor.transformed_remaining = 0.0


func runtime_snapshot() -> Dictionary:
	return {
		"transformed": actor.transformed,
		"transformed_remaining": roundi(actor.transformed_remaining * 10000.0),
	}


func apply_runtime_snapshot(snapshot: Dictionary) -> void:
	var active := bool(snapshot.get("transformed", actor.transformed))
	if active != actor.transformed:
		if active:
			_enter_transformed_form(false, false)
		else:
			_exit_transformed_form(false, false)
	actor.transformed_remaining = maxf(0.0, float(snapshot.get("transformed_remaining", roundi(actor.transformed_remaining * 10000.0))) / 10000.0)


func _enter_transformed_form(show_flash := true, emit_event := true) -> void:
	if actor.definition.transformed_sprite_texture == null or actor.definition.transform_duration <= 0.0:
		return
	actor.transformed = true
	actor.transformed_remaining = actor.definition.transform_duration
	actor.actor_presentation.set_transformed_visual(true)
	if show_flash:
		if not emit_event or not emit_hero_effect("sword_shield_transform", {"active": true}):
			actor.flash_remaining = 0.24


func _exit_transformed_form(start_cooldown: bool, show_flash := true) -> void:
	actor.transformed = false
	actor.transformed_remaining = 0.0
	actor.actor_presentation.set_transformed_visual(false)
	if show_flash:
		if not emit_hero_effect("sword_shield_transform", {"active": false}):
			actor.flash_remaining = 0.24
	if start_cooldown:
		var ultimate := actor.definition.ability_by_id("ultimate")
		if ultimate != null:
			actor.cooldowns["ultimate"] = ultimate.cooldown
	if actor.current_ability != null and actor.definition.transformed_ability_by_id(actor.current_ability.ability_id) == actor.current_ability:
		actor._cancel_current_ability()
	actor.resource_changed.emit(actor)
