class_name BattleStateDigest
extends RefCounted


static func build(tick: int, actors: Array[CombatActor], rng: BattleRng) -> Dictionary:
	var sorted_actors := actors.duplicate()
	sorted_actors.sort_custom(func(a: CombatActor, b: CombatActor) -> bool: return a.battle_id < b.battle_id)
	var actor_states: Array[Dictionary] = []
	for actor in sorted_actors:
		var cooldown_state: Dictionary = {}
		var cooldown_keys: Array = actor.cooldowns.keys()
		cooldown_keys.sort()
		for key in cooldown_keys:
			cooldown_state[str(key)] = _quantize(float(actor.cooldowns[key]))
		actor_states.append({
			"id": actor.battle_id,
			"position": _vector(actor.global_position),
			"velocity": _vector(actor.velocity),
			"facing": _vector(actor.facing),
			"hp": _quantize(actor.hp),
			"stamina": _quantize(actor.stamina),
			"energy": _quantize(actor.energy),
			"ability": "" if actor.current_ability == null else actor.current_ability.ability_id,
			"phase": actor.ability_phase,
			"cooldowns": cooldown_state,
			"statuses": actor.status_controller.snapshot(),
			"pending_damage": actor.pending_damage_snapshot(),
			"hero_runtime": actor.hero_runtime_snapshot(),
			"defeated": actor.is_defeated,
		})
	var unit_states: Array[Dictionary] = []
	if not sorted_actors.is_empty() and sorted_actors[0] != null and sorted_actors[0].is_inside_tree():
		for unit in sorted_actors[0].get_tree().get_nodes_in_group("deterministic_combat_units"):
			if unit.has_method("combat_snapshot"):
				unit_states.append(unit.call("combat_snapshot"))
	unit_states.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var type_compare := str(a.get("type", "")).naturalnocasecmp_to(str(b.get("type", "")))
		return int(a.get("id", 0)) < int(b.get("id", 0)) if type_compare == 0 else type_compare < 0
	)
	return {
		"tick": tick,
		"rng": rng.snapshot(),
		"actors": actor_states,
		"units": unit_states,
	}


static func checksum(tick: int, actors: Array[CombatActor], rng: BattleRng) -> String:
	var json := JSON.stringify(build(tick, actors, rng), "", true)
	return json.sha256_text()


static func _vector(value: Vector3) -> Array[int]:
	return [_quantize(value.x), _quantize(value.y), _quantize(value.z)]


static func _quantize(value: float) -> int:
	return roundi(value * 10000.0)
