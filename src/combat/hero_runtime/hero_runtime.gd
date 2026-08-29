class_name HeroRuntime
extends RefCounted

## Extension seam for hero-specific authoritative rules. Runtime instances have
## no process callback; their owner decides when they advance. Empty hooks keep
## heroes on the shared CombatActor implementation during incremental migration.

var actor: CombatActor


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func initialize() -> void:
	pass


func resolve_ability(_ability_id: String, fallback: AbilityDefinition) -> AbilityDefinition:
	return fallback


func select_ability(_ability_id: String, fallback: AbilityDefinition) -> AbilityDefinition:
	return fallback


func prepare_ability(_ability_id: String, _ability: AbilityDefinition) -> bool:
	return true


func has_special_resource(_ability_id: String) -> bool:
	return true


func commit_ability(_ability_id: String, _ability: AbilityDefinition, _bypass_cost: bool) -> void:
	actor.current_attack_damage_multiplier = 1.0


func activate_ability(_ability: AbilityDefinition, _attack_id: int) -> bool:
	return false


func before_shared_activation(_ability: AbilityDefinition, _attack_id: int) -> bool:
	return true


func before_startup_effects(_ability: AbilityDefinition) -> void:
	pass


func after_startup_effects(_ability: AbilityDefinition) -> void:
	pass


func on_basic_finished(_cooldown: float) -> void:
	pass


func on_hitbox_pulse(_ability: AbilityDefinition, _pulse_index: int) -> void:
	pass


func on_delayed_damage_queued(_target: CombatActor, _ability: AbilityDefinition) -> void:
	pass


func on_delayed_damage_resolved(_target: CombatActor, _ability: AbilityDefinition) -> void:
	pass


func update_continuous_ability(_delta: float) -> bool:
	return false


func update_pre_motion(_delta: float) -> bool:
	return false


func update_ground_special_motion(_delta: float) -> bool:
	return false


func cancel_special_for_command() -> bool:
	return false


func on_defeated() -> void:
	pass


func blocks_attack_from(_source: CombatActor) -> bool:
	return false


func on_attack_blocked(_source: CombatActor) -> void:
	pass


func movement_speed_multiplier() -> float:
	return 1.0


func apply_transformed_state(_active: bool) -> void:
	pass


func advance(_delta: float) -> void:
	pass


func reset() -> void:
	pass


func runtime_snapshot() -> Dictionary:
	return {}


func apply_runtime_snapshot(_snapshot: Dictionary) -> void:
	pass


func modify_outgoing_damage(_target: CombatActor, _ability: AbilityDefinition, base_damage: float) -> float:
	return base_damage


func on_killed_actor(_target: CombatActor, _ability: AbilityDefinition) -> void:
	pass


func begin_grapple_pull(_endpoint: Vector3) -> void:
	pass


func emit_hero_effect(vfx_id: String, payload: Dictionary = {}) -> bool:
	var authority := actor.match_authority()
	if authority == null:
		return false
	var event_payload := payload.duplicate(true)
	event_payload["vfx_id"] = vfx_id
	event_payload["source_id"] = actor.battle_id
	authority.emit_authoritative_event(AuthoritativeEvent.HERO_EFFECT, 0, event_payload)
	return true
