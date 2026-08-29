class_name NetworkCommandGateway
extends Node

signal command_confirmed(client_sequence: int, accepted: bool, reason: String, server_sequence: int)

const INPUT_DELAY_TICKS := 3

var session: BrawlNetworkSession
var stream: BattleCommandStream
var runtime: BattleCommandRuntime
var pending_server_commands: Dictionary = {}
var last_authoritative_sequence := 0
var last_processed_authoritative_sequence := 0
var replay_authoritative_commands := true
var accepting_commands := true


func setup(p_session: BrawlNetworkSession, p_stream: BattleCommandStream, p_runtime: BattleCommandRuntime, p_replay_authoritative_commands := true) -> void:
	session = p_session
	stream = p_stream
	runtime = p_runtime
	replay_authoritative_commands = p_replay_authoritative_commands
	session.authoritative_command_received.connect(_on_authoritative_command)
	session.command_result_received.connect(_on_command_result)
	if session.is_host():
		session.server_command_request_received.connect(_on_server_command_request)
		runtime.command_processed.connect(_on_server_command_processed)
	elif replay_authoritative_commands:
		runtime.command_processed.connect(_on_client_command_processed)


func submit(command: BattleCommand, _delay_ticks := 1) -> BattleCommand:
	if accepting_commands and session != null and stream != null:
		var observed_tick := stream.current_tick if session.is_host() else session.authority_tick
		session.submit_command_request(command, observed_tick)
	return command


func _on_server_command_request(peer_id: int, packet: Dictionary) -> void:
	if not session.is_host():
		return
	if not accepting_commands:
		session.reject_server_command_request(peer_id, int(packet.get("client_sequence", 0)), "比赛已经结束。")
		return
	var command_value = packet.get("command", {})
	if not command_value is Dictionary:
		return
	var command := BattleCommand.from_packet(command_value as Dictionary)
	var motor_value = runtime.motors.get(command.actor_id)
	if not motor_value is CommandMotor or (motor_value as CommandMotor).actor == null or (motor_value as CommandMotor).actor.is_defeated:
		session.reject_server_command_request(peer_id, int(packet.get("client_sequence", 0)), "角色已经阵亡或不存在。")
		return
	command.tick = stream.current_tick + INPUT_DELAY_TICKS
	stream.submit(command, INPUT_DELAY_TICKS)
	pending_server_commands[command.sequence] = {
		"peer_id": peer_id,
		"client_sequence": int(packet.get("client_sequence", 0)),
	}


func set_accepting_commands(value: bool) -> void:
	accepting_commands = value


func _on_server_command_processed(command: BattleCommand, accepted: bool) -> void:
	if not pending_server_commands.has(command.sequence):
		return
	var context := pending_server_commands[command.sequence] as Dictionary
	pending_server_commands.erase(command.sequence)
	var reason := "" if accepted else "服务器战斗状态拒绝了操作。"
	if accepted:
		command.sequence = session.reserve_server_command_sequence()
	session.complete_server_command(command, int(context.get("peer_id", 0)), int(context.get("client_sequence", 0)), accepted, reason)


func _on_authoritative_command(command_packet: Dictionary) -> void:
	if session.is_host() or stream == null:
		return
	var command := BattleCommand.from_packet(command_packet)
	if command.sequence <= last_authoritative_sequence:
		return
	last_authoritative_sequence = command.sequence
	if not replay_authoritative_commands:
		return
	# Server ticks belong to the authority's clock.  A client can run ahead or
	# behind (especially in separate local test processes), so replay confirmed
	# commands on the next local tick and preserve order with server_sequence.
	command.tick = stream.current_tick + 1
	stream.submit(command, 1)


func _on_command_result(client_sequence: int, accepted: bool, reason: String, server_sequence: int) -> void:
	command_confirmed.emit(client_sequence, accepted, reason, server_sequence)


func _on_client_command_processed(command: BattleCommand, _accepted: bool) -> void:
	last_processed_authoritative_sequence = maxi(last_processed_authoritative_sequence, command.sequence)
