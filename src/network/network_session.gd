class_name BrawlNetworkSession
extends Node

signal state_changed(state: State)
signal lobby_changed(players: Array)
signal error_changed(message: String)
signal match_config_received(config: Dictionary)
signal match_began
signal server_command_request_received(peer_id: int, packet: Dictionary)
signal authoritative_command_received(command_packet: Dictionary)
signal command_result_received(client_sequence: int, accepted: bool, reason: String, server_sequence: int)
signal state_snapshot_received(snapshot: Dictionary)
signal authoritative_event_received(event_envelope: Dictionary)
signal entity_snapshot_received(snapshot: Dictionary)

enum State { OFFLINE, CONNECTING, LOBBY, LOADING_MATCH, IN_MATCH }

const PROTOCOL_VERSION := 1
const GAME_VERSION := "0.4.3-score-ui"
const DEFAULT_PORT := 24567
const MAX_PLAYERS := 4
const SERVER_PEER_ID := 1
const MATCH_SCENE := "res://scenes/network_match.tscn"
const CONNECTION_TIMEOUT_MS := 6000

var state := State.OFFLINE
var players: Dictionary = {}
var match_config: Dictionary = {}
var last_error := ""
var local_display_name := "玩家"
var local_hero_id := "cheems_samurai"
var local_name_is_custom := false
var host_address := "127.0.0.1"
var next_player_id := 2
var loaded_peers: Dictionary = {}
var closing_session := false
var next_client_sequence := 1
var next_server_sequence := 1
var last_client_sequences: Dictionary = {}
var command_rate_windows: Dictionary = {}
var authority_tick := 0
var connection_started_msec := 0
var auto_name_suffix := 0
var match_map_definition: BrawlMapDefinition


func _ready() -> void:
	var cosmetic_rng := RandomNumberGenerator.new()
	cosmetic_rng.randomize()
	auto_name_suffix = cosmetic_rng.randi_range(1000, 9999)
	local_display_name = suggested_display_name(local_hero_id)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	if state == State.CONNECTING and connection_started_msec > 0 and Time.get_ticks_msec() - connection_started_msec >= CONNECTION_TIMEOUT_MS:
		close_session("未找到可加入的房间：请确认房主已经创建房间、IP 地址正确，并检查防火墙。")


func host_room(display_name: String = "玩家", hero_id: String = "cheems_samurai", port: int = DEFAULT_PORT) -> Error:
	close_session()
	local_display_name = _sanitize_name(display_name)
	local_hero_id = _sanitize_hero(hero_id)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_PLAYERS - 1)
	if result != OK:
		_set_error("创建房间失败：无法监听 UDP 端口 %d（错误 %d）" % [port, result])
		return result
	multiplayer.multiplayer_peer = peer
	closing_session = false
	next_player_id = 2
	players = {
		SERVER_PEER_ID: _make_player(1, SERVER_PEER_ID, local_display_name, local_hero_id, true),
	}
	host_address = "127.0.0.1"
	_set_error("")
	_set_state(State.LOBBY)
	_emit_lobby()
	return OK


func join_room(address: String, display_name: String = "玩家", hero_id: String = "cheems_samurai", port: int = DEFAULT_PORT) -> Error:
	close_session()
	local_display_name = _sanitize_name(display_name)
	local_hero_id = _sanitize_hero(hero_id)
	host_address = address.strip_edges() if not address.strip_edges().is_empty() else "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(host_address, port)
	if result != OK:
		_set_error("加入房间失败：无法连接 %s:%d（错误 %d）" % [host_address, port, result])
		return result
	multiplayer.multiplayer_peer = peer
	closing_session = false
	players.clear()
	match_config.clear()
	match_map_definition = null
	_set_error("")
	connection_started_msec = Time.get_ticks_msec()
	_set_state(State.CONNECTING)
	return OK


func close_session(reason := "") -> void:
	closing_session = true
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	match_config.clear()
	match_map_definition = null
	loaded_peers.clear()
	last_client_sequences.clear()
	command_rate_windows.clear()
	next_client_sequence = 1
	next_server_sequence = 1
	authority_tick = 0
	connection_started_msec = 0
	_set_state(State.OFFLINE)
	if not reason.is_empty():
		_set_error(reason)
	closing_session = false


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func local_peer_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0


func peer_round_trip_time_ms(peer_id: int) -> int:
	if peer_id == local_peer_id():
		return 0
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return -1
	var peer := enet.get_peer(peer_id)
	if peer == null:
		return -1
	return maxi(0, int(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))


func local_player() -> Dictionary:
	return players.get(local_peer_id(), {}) as Dictionary


func roster() -> Array:
	var result: Array = []
	var peer_ids: Array = players.keys()
	peer_ids.sort()
	for peer_id_value in peer_ids:
		result.append((players[peer_id_value] as Dictionary).duplicate(true))
	return result


func request_profile(display_name: String, hero_id: String) -> void:
	local_display_name = _sanitize_name(display_name)
	local_hero_id = _sanitize_hero(hero_id)
	if state != State.LOBBY:
		return
	var packet := {"display_name": local_display_name, "hero_id": local_hero_id}
	if is_host():
		_apply_profile(SERVER_PEER_ID, packet)
	else:
		_request_profile.rpc_id(SERVER_PEER_ID, packet)


func suggested_display_name(hero_id: String) -> String:
	var safe_hero := _sanitize_hero(hero_id)
	var suffix := auto_name_suffix if auto_name_suffix >= 1000 else 1000
	return "%s_%04d" % [HeroCatalog.display_name(safe_hero), suffix]


func set_local_ready(ready: bool) -> void:
	if state != State.LOBBY:
		return
	if is_host():
		_apply_ready(SERVER_PEER_ID, ready)
	else:
		_request_ready.rpc_id(SERVER_PEER_ID, ready)


func can_host_start() -> bool:
	if not is_host() or state != State.LOBBY or players.size() < 2:
		return false
	for player_value in players.values():
		if not bool((player_value as Dictionary).get("ready", false)):
			return false
	return true


func host_start_match() -> bool:
	if not can_host_start():
		_set_error("至少需要两名玩家，并且所有玩家都已准备。")
		return false
	match_config = _build_match_config()
	if match_config.is_empty():
		_set_error("无法加载联机地图，比赛未开始。")
		return false
	loaded_peers.clear()
	_set_state(State.LOADING_MATCH)
	_receive_match_start.rpc(match_config)
	_apply_match_start(match_config)
	return true


func report_match_loaded() -> void:
	if state != State.LOADING_MATCH:
		return
	if is_host():
		_mark_peer_loaded(SERVER_PEER_ID)
	else:
		_report_loaded.rpc_id(SERVER_PEER_ID, int(match_config.get("match_id", 0)))


func submit_command_request(command: BattleCommand, client_tick: int) -> int:
	if state != State.IN_MATCH or command == null:
		return 0
	var client_sequence := next_client_sequence
	next_client_sequence += 1
	var packet := {
		"protocol_version": PROTOCOL_VERSION,
		"match_id": int(match_config.get("match_id", 0)),
		"client_sequence": client_sequence,
		"client_tick": client_tick,
		"command": command.to_packet(),
	}
	if is_host():
		_accept_command_request(SERVER_PEER_ID, packet)
	else:
		_request_command.rpc_id(SERVER_PEER_ID, packet)
	return client_sequence


func reserve_server_command_sequence() -> int:
	if not is_host():
		return 0
	var value := next_server_sequence
	next_server_sequence += 1
	return value


func latest_server_command_sequence() -> int:
	return maxi(0, next_server_sequence - 1)


func complete_server_command(command: BattleCommand, source_peer_id: int, client_sequence: int, accepted: bool, reason := "") -> void:
	if not is_host() or command == null:
		return
	if accepted:
		_authoritative_command.rpc(command.to_packet())
	_send_command_result(source_peer_id, client_sequence, accepted, reason, command.sequence)


func reject_server_command_request(source_peer_id: int, client_sequence: int, reason: String) -> void:
	if is_host():
		_send_command_result(source_peer_id, client_sequence, false, reason, 0)


func broadcast_state_snapshot(snapshot: Dictionary) -> void:
	if is_host() and state == State.IN_MATCH:
		_state_snapshot.rpc(snapshot)


func broadcast_authoritative_event(event_envelope: Dictionary) -> void:
	if is_host() and state == State.IN_MATCH:
		_authoritative_event.rpc(event_envelope)


func broadcast_entity_snapshot(snapshot: Dictionary) -> void:
	if is_host() and state == State.IN_MATCH:
		_entity_snapshot.rpc(snapshot)


func local_addresses() -> Array[String]:
	var result: Array[String] = []
	for address in IP.get_local_addresses():
		if ":" not in address and not address.begins_with("127.") and address != "0.0.0.0":
			result.append(address)
	result.sort()
	return result


func preferred_local_address() -> String:
	var addresses := local_addresses()
	if addresses.is_empty():
		return "127.0.0.1"
	addresses.sort_custom(func(a: String, b: String) -> bool: return _local_address_score(a) < _local_address_score(b))
	return addresses[0]


func _local_address_score(address: String) -> int:
	var score := 1000
	if address.begins_with("192.168."):
		score = 0
	elif address.begins_with("10."):
		score = 100
	elif address.begins_with("172."):
		var parts := address.split(".")
		if parts.size() >= 2 and int(parts[1]) >= 16 and int(parts[1]) <= 31:
			score = 200
	if address.ends_with(".1"):
		score += 25
	return score


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_join(hello: Dictionary) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if state != State.LOBBY:
		_join_rejected.rpc_id(sender, "比赛已经开始，暂时不能中途加入。")
		return
	if int(hello.get("protocol_version", -1)) != PROTOCOL_VERSION or str(hello.get("game_version", "")) != GAME_VERSION:
		_join_rejected.rpc_id(sender, "版本不一致：房主使用协议 %d / %s。" % [PROTOCOL_VERSION, GAME_VERSION])
		return
	if players.size() >= MAX_PLAYERS:
		_join_rejected.rpc_id(sender, "房间已满。")
		return
	if players.has(sender):
		_broadcast_lobby()
		return
	players[sender] = _make_player(next_player_id, sender, _sanitize_name(str(hello.get("display_name", "玩家"))), _sanitize_hero(str(hello.get("hero_id", "cheems_samurai"))), false)
	next_player_id += 1
	_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_profile(packet: Dictionary) -> void:
	if is_host() and state == State.LOBBY:
		_apply_profile(multiplayer.get_remote_sender_id(), packet)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_ready(ready: bool) -> void:
	if is_host() and state == State.LOBBY:
		_apply_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("any_peer", "call_remote", "reliable", 1)
func _request_command(packet: Dictionary) -> void:
	if is_host():
		_accept_command_request(multiplayer.get_remote_sender_id(), packet)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_lobby(packet: Array) -> void:
	players.clear()
	for player_value in packet:
		if player_value is Dictionary:
			var player := (player_value as Dictionary).duplicate(true)
			players[int(player.get("peer_id", 0))] = player
	if state == State.CONNECTING:
		_set_state(State.LOBBY)
	_emit_lobby()


@rpc("authority", "call_remote", "reliable", 0)
func _join_rejected(reason: String) -> void:
	close_session(reason)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_match_start(config: Dictionary) -> void:
	_apply_match_start(config)


@rpc("any_peer", "call_remote", "reliable", 0)
func _report_loaded(match_id: int) -> void:
	if is_host() and state == State.LOADING_MATCH and match_id == int(match_config.get("match_id", -1)):
		_mark_peer_loaded(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable", 0)
func _receive_match_began(match_id: int) -> void:
	if match_id != int(match_config.get("match_id", -1)):
		return
	_set_state(State.IN_MATCH)
	match_began.emit()


@rpc("authority", "call_remote", "reliable", 1)
func _authoritative_command(command_packet: Dictionary) -> void:
	authoritative_command_received.emit(command_packet)


@rpc("authority", "call_remote", "reliable", 1)
func _receive_command_result(client_sequence: int, accepted: bool, reason: String, server_sequence: int) -> void:
	command_result_received.emit(client_sequence, accepted, reason, server_sequence)


@rpc("authority", "call_remote", "unreliable", 2)
func _state_snapshot(snapshot: Dictionary) -> void:
	state_snapshot_received.emit(snapshot)


@rpc("authority", "call_remote", "reliable", 1)
func _authoritative_event(event_envelope: Dictionary) -> void:
	authoritative_event_received.emit(event_envelope)


@rpc("authority", "call_remote", "unreliable", 2)
func _entity_snapshot(snapshot: Dictionary) -> void:
	entity_snapshot_received.emit(snapshot)


func _on_peer_connected(_peer_id: int) -> void:
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if closing_session or not is_host():
		return
	if players.erase(peer_id):
		loaded_peers.erase(peer_id)
		_broadcast_lobby()
		_check_all_loaded()


func _on_connected_to_server() -> void:
	connection_started_msec = 0
	_request_join.rpc_id(SERVER_PEER_ID, {
		"protocol_version": PROTOCOL_VERSION,
		"game_version": GAME_VERSION,
		"display_name": local_display_name,
		"hero_id": local_hero_id,
	})


func _on_connection_failed() -> void:
	if not closing_session:
		close_session("连接失败：请检查 IP、端口和房主防火墙设置。")


func _on_server_disconnected() -> void:
	if closing_session:
		return
	var was_in_match := state in [State.LOADING_MATCH, State.IN_MATCH]
	close_session("房主已离开，房间关闭。")
	if was_in_match:
		get_tree().change_scene_to_file.bind("res://scenes/launcher.tscn").call_deferred()


func _apply_profile(peer_id: int, packet: Dictionary) -> void:
	if not players.has(peer_id):
		return
	var player := players[peer_id] as Dictionary
	player["display_name"] = _sanitize_name(str(packet.get("display_name", player.get("display_name", "玩家"))))
	player["hero_id"] = _sanitize_hero(str(packet.get("hero_id", player.get("hero_id", "cheems_samurai"))))
	player["ready"] = false
	players[peer_id] = player
	_broadcast_lobby()


func _apply_ready(peer_id: int, ready: bool) -> void:
	if not players.has(peer_id):
		return
	var player := players[peer_id] as Dictionary
	player["ready"] = ready
	players[peer_id] = player
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	var packet := roster()
	_receive_lobby.rpc(packet)
	_emit_lobby()


func _emit_lobby() -> void:
	lobby_changed.emit(roster())


func _apply_match_start(config: Dictionary) -> void:
	var map_id := str(config.get("map_id", ""))
	var definition := BrawlMapCatalog.load_definition(map_id)
	if definition == null or definition.map_version != int(config.get("map_version", 0)):
		close_session("地图 %s 缺失或版本不一致，无法进入比赛。" % map_id)
		return
	match_map_definition = definition
	match_config = config.duplicate(true)
	next_client_sequence = 1
	next_server_sequence = 1
	last_client_sequences.clear()
	command_rate_windows.clear()
	authority_tick = 0
	_set_state(State.LOADING_MATCH)
	match_config_received.emit(match_config)
	if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != MATCH_SCENE:
		get_tree().change_scene_to_file.bind(MATCH_SCENE).call_deferred()


func _mark_peer_loaded(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	loaded_peers[peer_id] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	if not is_host() or state != State.LOADING_MATCH:
		return
	for participant_value in match_config.get("participants", []):
		var participant := participant_value as Dictionary
		var peer_id := int(participant.get("peer_id", 0))
		if players.has(peer_id) and not loaded_peers.has(peer_id):
			return
	var match_id := int(match_config.get("match_id", 0))
	_receive_match_began.rpc(match_id)
	_receive_match_began(match_id)


func _build_match_config() -> Dictionary:
	var definition := BrawlMapCatalog.default_network_map()
	if definition == null:
		return {}
	match_map_definition = definition
	var participants: Array = []
	var room_players := roster()
	for index in range(room_players.size()):
		var player := room_players[index] as Dictionary
		var spawn_position := definition.spawn_position(index)
		participants.append({
			"player_id": int(player.get("player_id", 0)),
			"peer_id": int(player.get("peer_id", 0)),
			"actor_id": index + 1,
			"display_name": str(player.get("display_name", "玩家")),
			"hero_id": str(player.get("hero_id", "cheems_samurai")),
			"spawn_id": str(definition.spawn_points[index % definition.spawn_points.size()].get("id", "")),
			"spawn_x": spawn_position.x,
			"spawn_z": spawn_position.z,
		})
	return {
		"protocol_version": PROTOCOL_VERSION,
		"game_version": GAME_VERSION,
		"match_id": Time.get_ticks_msec(),
		"map_id": definition.map_id,
		"map_version": definition.map_version,
		"seed": randi(),
		"participants": participants,
	}


func _accept_command_request(peer_id: int, packet: Dictionary) -> void:
	var client_sequence := int(packet.get("client_sequence", 0))
	var validation := _validate_command_request(peer_id, packet)
	if not bool(validation.get("accepted", false)):
		_send_command_result(peer_id, client_sequence, false, str(validation.get("reason", "非法操作")), 0)
		return
	server_command_request_received.emit(peer_id, {
		"client_sequence": client_sequence,
		"client_tick": int(packet.get("client_tick", 0)),
		"command": validation.get("command", {}),
	})


func _validate_command_request(peer_id: int, packet: Dictionary) -> Dictionary:
	if not is_host() or state != State.IN_MATCH:
		return _command_rejection("比赛尚未进入可操作状态。")
	if int(packet.get("protocol_version", -1)) != PROTOCOL_VERSION or int(packet.get("match_id", -1)) != int(match_config.get("match_id", 0)):
		return _command_rejection("协议或比赛 ID 不匹配。")
	if not players.has(peer_id):
		return _command_rejection("发送者不在当前房间。")
	var client_sequence := int(packet.get("client_sequence", 0))
	var last_sequence := int(last_client_sequences.get(peer_id, 0))
	if client_sequence <= last_sequence:
		return _command_rejection("操作序号重复或倒退。")
	if client_sequence > last_sequence + 256:
		return _command_rejection("操作序号超出允许窗口。")
	if not _consume_command_rate(peer_id):
		return _command_rejection("操作频率过高。")
	last_client_sequences[peer_id] = client_sequence
	var command_value = packet.get("command", {})
	if not command_value is Dictionary:
		return _command_rejection("命令包格式错误。")
	var command_packet := command_value as Dictionary
	var actor_id := int(command_packet.get("actor_id", 0))
	if actor_id != _owned_actor_id(peer_id):
		return _command_rejection("actor_id 不属于发送者。")
	var type := int(command_packet.get("type", -1))
	if type < BattleCommand.Type.MOVE_TO or type > BattleCommand.Type.CANCEL_ABILITY:
		return _command_rejection("未知命令类型。")
	var ability_id := str(command_packet.get("ability_id", ""))
	if type in [BattleCommand.Type.CAST_ABILITY, BattleCommand.Type.BEGIN_ABILITY, BattleCommand.Type.END_ABILITY]:
		if ability_id not in ["skill_q", "skill_w", "skill_e", "ultimate"]:
			return _command_rejection("技能 ID 不合法。")
	else:
		ability_id = ""
	var target_value = command_packet.get("target", [])
	var direction_value = command_packet.get("direction", [])
	if not target_value is Array or (target_value as Array).size() < 3 or not direction_value is Array or (direction_value as Array).size() < 3:
		return _command_rejection("坐标字段格式错误。")
	var target := target_value as Array
	var direction := direction_value as Array
	var target_x := float(target[0])
	var target_z := float(target[2])
	var direction_x := float(direction[0])
	var direction_z := float(direction[2])
	if not is_finite(target_x) or not is_finite(target_z) or not is_finite(direction_x) or not is_finite(direction_z):
		return _command_rejection("坐标包含非有限数值。")
	var definition := match_map_definition
	if definition == null:
		definition = BrawlMapCatalog.load_definition(str(match_config.get("map_id", "")))
	if definition == null or not definition.playable_bounds(0.0).has_point(Vector2(target_x, target_z)):
		return _command_rejection("目标点超出地图边界。")
	var planar_direction := Vector2(direction_x, direction_z)
	if planar_direction.length_squared() > 1.001:
		planar_direction = planar_direction.normalized()
	return {
		"accepted": true,
		"command": {
			"tick": 0,
			"sequence": 0,
			"actor_id": actor_id,
			"type": type,
			"target": [target_x, 0.0, target_z],
			"direction": [planar_direction.x, 0.0, planar_direction.y],
			"ability_id": ability_id,
		},
	}


func _owned_actor_id(peer_id: int) -> int:
	for participant_value in match_config.get("participants", []):
		var participant := participant_value as Dictionary
		if int(participant.get("peer_id", 0)) == peer_id:
			return int(participant.get("actor_id", 0))
	return 0


func _consume_command_rate(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	var window: Dictionary = command_rate_windows.get(peer_id, {"started": now, "count": 0})
	if now - int(window.get("started", now)) >= 1000:
		window = {"started": now, "count": 0}
	var count := int(window.get("count", 0)) + 1
	window["count"] = count
	command_rate_windows[peer_id] = window
	return count <= 60


func _send_command_result(peer_id: int, client_sequence: int, accepted: bool, reason: String, server_sequence: int) -> void:
	if peer_id == SERVER_PEER_ID:
		command_result_received.emit(client_sequence, accepted, reason, server_sequence)
	elif players.has(peer_id):
		_receive_command_result.rpc_id(peer_id, client_sequence, accepted, reason, server_sequence)


func _command_rejection(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}


func _make_player(player_id: int, peer_id: int, display_name: String, hero_id: String, host: bool) -> Dictionary:
	return {
		"player_id": player_id,
		"peer_id": peer_id,
		"display_name": display_name,
		"hero_id": hero_id,
		"ready": false,
		"connected": true,
		"is_host": host,
	}


func _sanitize_name(value: String) -> String:
	var result := value.strip_edges().substr(0, 20)
	return result if not result.is_empty() else "玩家"


func _sanitize_hero(value: String) -> String:
	return value if value in HeroCatalog.IDS else "cheems_samurai"


func _set_state(value: State) -> void:
	if state == value:
		return
	state = value
	state_changed.emit(state)


func _set_error(message: String) -> void:
	last_error = message
	error_changed.emit(last_error)
