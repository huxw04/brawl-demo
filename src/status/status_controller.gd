class_name StatusController
extends Node

signal changed
signal periodic_damage_requested(amount: float, source_actor_id: int, effect_id: String)

var active: Dictionary = {}


func apply(definition: StatusEffectDefinition, source_actor_id := 0) -> bool:
	if definition == null or definition.effect_id.is_empty():
		return false
	if definition.is_control_effect() and has_tag("control_immune"):
		return false
	if active.has(definition.effect_id):
		var existing := active[definition.effect_id] as StatusEffectInstance
		match definition.stack_mode:
			StatusEffectDefinition.StackMode.ADD_STACK:
				existing.stacks = mini(definition.max_stacks, existing.stacks + 1)
				existing.remaining = maxf(existing.remaining, definition.duration)
			StatusEffectDefinition.StackMode.REPLACE:
				existing.setup(definition, source_actor_id)
			_:
				existing.remaining = definition.duration
	else:
		var instance := StatusEffectInstance.new()
		instance.setup(definition, source_actor_id)
		active[definition.effect_id] = instance
	changed.emit()
	return true


func advance(delta: float) -> void:
	var expired: Array[String] = []
	for id in active.keys():
		var instance := active[id] as StatusEffectInstance
		instance.remaining -= delta
		if instance.definition.tick_interval > 0.0:
			instance.tick_remaining -= delta
			while instance.tick_remaining <= 0.0 and instance.remaining > 0.0:
				instance.tick_remaining += instance.definition.tick_interval
				if instance.definition.periodic_damage > 0.0:
					periodic_damage_requested.emit(
						instance.definition.periodic_damage * instance.stacks,
						instance.source_actor_id,
						instance.definition.effect_id,
					)
		if instance.remaining <= 0.0:
			expired.append(id)
	for id in expired:
		active.erase(id)
	if not expired.is_empty():
		changed.emit()


func remove(effect_id: String) -> void:
	if active.erase(effect_id):
		changed.emit()


func clear() -> void:
	if active.is_empty():
		return
	active.clear()
	changed.emit()


func has_tag(tag: String) -> bool:
	for value in active.values():
		var instance := value as StatusEffectInstance
		if instance.definition.tags.has(tag):
			return true
	return false


func multiplier(stat_id: String) -> float:
	var result := 1.0
	for value in active.values():
		var instance := value as StatusEffectInstance
		if instance.definition.stat_multipliers.has(stat_id):
			result *= pow(float(instance.definition.stat_multipliers[stat_id]), instance.stacks)
	return result


func summaries() -> Array[String]:
	var result: Array[String] = []
	for value in active.values():
		var instance := value as StatusEffectInstance
		result.append("%s %.1fs" % [instance.definition.display_name, instance.remaining])
	return result


func overhead_text() -> String:
	for priority_tag in ["untargetable", "stunned", "control_immune", "stealth"]:
		for value in active.values():
			var instance := value as StatusEffectInstance
			if instance.definition.tags.has(priority_tag):
				return instance.definition.display_name
	return ""


func has_visual(visual_id: String) -> bool:
	for value in active.values():
		var instance := value as StatusEffectInstance
		if instance.definition.visual_id == visual_id:
			return true
	return false


func snapshot() -> Array[Dictionary]:
	var ids: Array = active.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	for id in ids:
		var instance := active[id] as StatusEffectInstance
		result.append({
			"id": str(id),
			"source": instance.source_actor_id,
			"remaining": roundi(instance.remaining * 10000.0),
			"stacks": instance.stacks,
			"tick_remaining": roundi(instance.tick_remaining * 10000.0),
		})
	return result
