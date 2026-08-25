class_name StatusEffectInstance
extends RefCounted

var definition: StatusEffectDefinition
var source_actor_id := 0
var remaining := 0.0
var stacks := 1
var tick_remaining := 0.0


func setup(p_definition: StatusEffectDefinition, p_source_actor_id: int) -> void:
	definition = p_definition
	source_actor_id = p_source_actor_id
	remaining = definition.duration
	stacks = 1
	tick_remaining = definition.tick_interval
