class_name CombatStatuses
extends RefCounted


static func stunned(duration: float) -> StatusEffectDefinition:
	return _effect("stunned", "眩晕", duration, ["control", "stunned"], {}, "stun")


static func rooted(duration: float) -> StatusEffectDefinition:
	return _effect("rooted", "定身", duration, ["control", "stunned", "rooted"], {}, "root")


static func control_immune(duration: float) -> StatusEffectDefinition:
	return _effect("control_immune", "霸体", duration, ["control_immune"], {}, "armor")


static func untargetable(duration: float) -> StatusEffectDefinition:
	return _effect("untargetable", "无法选中", duration, ["untargetable"], {}, "untargetable")


static func stealth(duration: float) -> StatusEffectDefinition:
	return _effect("bear_stealth", "隐身", duration, ["stealth"], {}, "stealth")


static func slow(duration: float, ratio: float) -> StatusEffectDefinition:
	return _effect("slow", "减速", duration, [], {"move_speed": ratio}, "slow")


static func poison(duration: float, tick_damage := 3.0) -> StatusEffectDefinition:
	var effect := _effect("poison", "中毒", duration, [], {}, "poison")
	effect.tick_interval = 0.6
	effect.periodic_damage = tick_damage
	return effect


static func _effect(id: String, label: String, duration: float, tags: Array, multipliers: Dictionary, visual: String) -> StatusEffectDefinition:
	var effect := StatusEffectDefinition.new()
	effect.effect_id = id
	effect.display_name = label
	effect.duration = duration
	effect.tags = PackedStringArray(tags)
	effect.stat_multipliers = multipliers
	effect.visual_id = visual
	return effect
