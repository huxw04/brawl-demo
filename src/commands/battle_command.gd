class_name BattleCommand
extends RefCounted

enum Type {
	MOVE_TO,
	STOP,
	BASIC_ATTACK,
	CAST_ABILITY,
	BEGIN_ABILITY,
	END_ABILITY,
	ROLL,
	JUMP,
	CANCEL_ABILITY,
}

var tick := 0
var sequence := 0
var actor_id := 0
var type := Type.STOP
var world_target := Vector3.ZERO
var direction := Vector3.ZERO
var ability_id := ""


static func create(p_actor_id: int, p_type: Type, p_target := Vector3.ZERO) -> BattleCommand:
	var command := BattleCommand.new()
	command.actor_id = p_actor_id
	command.type = p_type
	command.world_target = p_target
	return command


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"sequence": sequence,
		"actor_id": actor_id,
		"type": type,
		"target": [world_target.x, world_target.y, world_target.z],
		"direction": [direction.x, direction.y, direction.z],
		"ability_id": ability_id,
	}


func to_packet() -> Dictionary:
	return to_dict()


static func from_dict(data: Dictionary) -> BattleCommand:
	var command := BattleCommand.new()
	command.tick = int(data.get("tick", 0))
	command.sequence = int(data.get("sequence", 0))
	command.actor_id = int(data.get("actor_id", 0))
	command.type = int(data.get("type", Type.STOP)) as Type
	var target: Array = data.get("target", [0.0, 0.0, 0.0]) as Array
	var facing: Array = data.get("direction", [0.0, 0.0, 0.0]) as Array
	if target.size() < 3:
		target = [0.0, 0.0, 0.0]
	if facing.size() < 3:
		facing = [0.0, 0.0, 0.0]
	command.world_target = Vector3(float(target[0]), float(target[1]), float(target[2]))
	command.direction = Vector3(float(facing[0]), float(facing[1]), float(facing[2]))
	command.ability_id = str(data.get("ability_id", ""))
	return command


static func from_packet(packet: Dictionary) -> BattleCommand:
	return from_dict(packet)
