class_name BattleRng
extends RefCounted

var initial_seed := 0
var draws := 0
var generator := RandomNumberGenerator.new()


func _init(seed := 0) -> void:
	reset(seed)


func reset(seed: int) -> void:
	initial_seed = seed
	draws = 0
	generator.seed = seed


func randf_value() -> float:
	draws += 1
	return generator.randf()


func randf_between(minimum: float, maximum: float) -> float:
	draws += 1
	return generator.randf_range(minimum, maximum)


func randi_between(minimum: int, maximum: int) -> int:
	draws += 1
	return generator.randi_range(minimum, maximum)


func snapshot() -> Dictionary:
	# State is serialized as text so a 64-bit RNG state is not rounded by JSON.
	return {"seed": str(initial_seed), "state": str(generator.state), "draws": draws}
