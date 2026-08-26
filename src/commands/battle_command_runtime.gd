class_name BattleCommandRuntime
extends Node

signal command_processed(command: BattleCommand, accepted: bool)
signal movement_destination_resolved(actor_id: int, requested: Vector3, resolved: Vector3, reachable: bool)

var stream: BattleCommandStream
var pathfinder: ArenaPathfinder
var motors: Dictionary = {}
var running := true


func setup(p_stream: BattleCommandStream, p_pathfinder: ArenaPathfinder) -> void:
	stream = p_stream
	pathfinder = p_pathfinder


func register_actor(actor: CombatActor) -> CommandMotor:
	unregister_actor(actor.battle_id)
	var motor := CommandMotor.new()
	motor.name = "CommandMotor_%d" % actor.battle_id
	add_child(motor)
	motor.setup(actor, pathfinder)
	motors[actor.battle_id] = motor
	return motor


func unregister_actor(actor_id: int) -> void:
	var existing = motors.get(actor_id)
	if existing is CommandMotor:
		(existing as CommandMotor).stop()
		(existing as CommandMotor).queue_free()
	motors.erase(actor_id)


func stop_all() -> void:
	for motor in motors.values():
		(motor as CommandMotor).stop()


func _physics_process(_delta: float) -> void:
	if not running or stream == null:
		return
	advance_tick()


func advance_tick() -> void:
	if stream == null:
		return
	for command in stream.advance_tick():
		var motor = motors.get(command.actor_id)
		var accepted := false
		if motor is CommandMotor:
			accepted = (motor as CommandMotor).apply_command(command)
		command_processed.emit(command, accepted)
		if command.type == BattleCommand.Type.MOVE_TO and motor is CommandMotor:
			movement_destination_resolved.emit(command.actor_id, command.world_target, (motor as CommandMotor).resolved_destination, accepted)
	for motor in motors.values():
		(motor as CommandMotor).advance_movement()
