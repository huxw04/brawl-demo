class_name CombatResourceRuntime
extends RefCounted

## Resource rules remain explicitly driven by CombatActor. This runtime has no
## process callback, so a future authority layer can decide whether it advances.
## Public state stays on CombatActor until the network snapshot contract changes.

var actor: CombatActor


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func advance_timers(delta: float) -> void:
	for key in actor.cooldowns.keys():
		actor.cooldowns[key] = maxf(0.0, float(actor.cooldowns[key]) - delta)
	actor.stamina_regen_block = maxf(0.0, actor.stamina_regen_block - delta)


func regenerate_stamina(delta: float) -> void:
	if actor.stamina_regen_block > 0.0 or actor.stamina >= actor.definition.max_stamina or actor.is_defeated:
		return
	actor.stamina = minf(actor.definition.max_stamina, actor.stamina + actor.definition.stamina_regen * delta)
	actor.resource_changed.emit(actor)


func can_pay(ability_id: String, ability: AbilityDefinition) -> bool:
	return (
		float(actor.cooldowns.get(ability_id, 0.0)) <= 0.0
		and actor.stamina >= ability.stamina_cost
		and actor.energy >= ability.energy_cost
	)


func pay(ability: AbilityDefinition) -> void:
	spend_stamina(ability.stamina_cost)
	actor.energy = maxf(0.0, actor.energy - ability.energy_cost)


func spend_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	actor.stamina = maxf(0.0, actor.stamina - amount)
	actor.stamina_regen_block = actor.definition.stamina_regen_delay
	actor.resource_changed.emit(actor)


func gain_energy(amount: float) -> void:
	actor.energy = minf(actor.definition.max_energy, actor.energy + amount)
	actor.resource_changed.emit(actor)


func reset() -> void:
	actor.stamina = actor.definition.max_stamina
	actor.energy = actor.definition.max_energy if actor.definition.starts_with_full_energy else 0.0
	actor.cooldowns.clear()
	actor.stamina_regen_block = 0.0


func cooldown_ratio(ability_id: String) -> float:
	var ability := actor.ability_by_id(ability_id)
	if ability == null:
		ability = actor.definition.ability_by_id(ability_id)
	if ability == null or ability.cooldown <= 0.0:
		return 0.0
	return clampf(float(actor.cooldowns.get(ability_id, 0.0)) / ability.cooldown, 0.0, 1.0)
