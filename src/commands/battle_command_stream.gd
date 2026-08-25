class_name BattleCommandStream
extends Node

signal command_submitted(command: BattleCommand)

var current_tick := 0
var next_sequence := 1
var pending: Dictionary = {}
var history: Array[BattleCommand] = []


func submit(command: BattleCommand, delay_ticks := 1) -> BattleCommand:
	if command.sequence <= 0:
		command.sequence = next_sequence
		next_sequence += 1
	if command.tick <= current_tick:
		command.tick = current_tick + maxi(1, delay_ticks)
	if not pending.has(command.tick):
		pending[command.tick] = []
	var commands: Array = pending[command.tick]
	commands.append(command)
	history.append(command)
	command_submitted.emit(command)
	return command


func advance_tick() -> Array[BattleCommand]:
	current_tick += 1
	var result: Array[BattleCommand] = []
	if pending.has(current_tick):
		for value in pending[current_tick]:
			result.append(value as BattleCommand)
		pending.erase(current_tick)
	result.sort_custom(func(a: BattleCommand, b: BattleCommand) -> bool: return a.sequence < b.sequence)
	return result


func reset() -> void:
	current_tick = 0
	next_sequence = 1
	pending.clear()
	history.clear()


func serialized_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for command in history:
		result.append(command.to_dict())
	return result
