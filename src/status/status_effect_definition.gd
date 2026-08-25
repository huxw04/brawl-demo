class_name StatusEffectDefinition
extends Resource

enum StackMode { REFRESH, ADD_STACK, REPLACE }

@export var effect_id := "status"
@export var display_name := "Status"
@export var duration := 1.0
@export var stack_mode := StackMode.REFRESH
@export var max_stacks := 1
@export var tags: PackedStringArray = []
# Multipliers are composed multiplicatively; e.g. move_speed = 0.7 means 30% slow.
@export var stat_multipliers: Dictionary = {}
@export var tick_interval := 0.0
@export var periodic_damage := 0.0
@export var visual_id := ""


func is_control_effect() -> bool:
	return tags.has("control") or tags.has("stunned") or tags.has("rooted")
