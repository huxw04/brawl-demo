extends Node3D

const ActorScript = preload("res://src/combat/combat_actor.gd")
const ArenaScript = preload("res://src/presentation/arena_world.gd")
const GatewayScript = preload("res://src/network/network_command_gateway.gd")
const MoveIndicatorScript = preload("res://src/presentation/move_destination_indicator.gd")
const TargetingPreviewScript = preload("res://src/presentation/ability_targeting_preview.gd")
const HUDScript = preload("res://src/ui/battle_hud.gd")
const MatchAuthorityScript = preload("res://src/core/match_authority.gd")
const MatchReplicaScript = preload("res://src/network/match_replica.gd")
const AuthorityEventPresentationScript = preload("res://src/presentation/authority_event_presentation.gd")
const RespawnManagerScript = preload("res://src/match/brawl_respawn_manager.gd")
const ScoreManagerScript = preload("res://src/match/brawl_score_manager.gd")
const ScoreboardScript = preload("res://src/ui/brawl_scoreboard.gd")

const SNAPSHOT_INTERVAL := 1.0 / 12.0
const MATCH_STATE_INTERVAL := 1.0

var arena: ArenaWorld
var actors_by_peer: Dictionary = {}
var actors_by_id: Dictionary = {}
var local_actor: CombatActor
var command_stream: BattleCommandStream
var command_runtime: BattleCommandRuntime
var command_gateway: NetworkCommandGateway
var player_controller: MobaPlayerController
var pathfinder: ArenaPathfinder
var move_indicator: MoveDestinationIndicator
var targeting_preview: AbilityTargetingPreview
var hud: BattleHUD
var status_label: Label
var roster_label: Label
var network_label: Label
var diagnostics_panel: PanelContainer
var diagnostics_label: Label
var snapshot_elapsed := 0.0
var match_state_elapsed := 0.0
var match_running := false
var leaving := false
var match_authority: MatchAuthority
var match_replica: MatchReplica
var authority_presentation: AuthorityEventPresentation
var battle_rng: BattleRng
var respawn_manager: BrawlRespawnManager
var score_manager: BrawlScoreManager
var scoreboard: BrawlScoreboard


func _ready() -> void:
	if NetworkSession.state != BrawlNetworkSession.State.LOADING_MATCH or NetworkSession.match_config.is_empty():
		NetworkSession.close_session("联机比赛配置缺失。")
		get_tree().change_scene_to_file.bind("res://scenes/launcher.tscn").call_deferred()
		return
	if NetworkSession.is_host():
		match_authority = MatchAuthorityScript.new() as MatchAuthority
		match_authority.name = "MatchAuthority"
		add_child(match_authority)
		match_authority.authoritative_event_emitted.connect(_on_authoritative_event_emitted)
		authority_presentation = AuthorityEventPresentationScript.new() as AuthorityEventPresentation
		authority_presentation.name = "AuthorityEventPresentation"
		add_child(authority_presentation)
		authority_presentation.setup(match_authority)
	else:
		match_replica = MatchReplicaScript.new() as MatchReplica
		match_replica.name = "MatchReplica"
		add_child(match_replica)
		match_replica.setup(int(NetworkSession.match_config.get("match_id", 0)))
		authority_presentation = AuthorityEventPresentationScript.new() as AuthorityEventPresentation
		authority_presentation.name = "AuthorityEventPresentation"
		add_child(authority_presentation)
		authority_presentation.setup_source(match_replica)
	authority_presentation.event_consumed.connect(_on_authority_event_consumed)
	arena = ArenaScript.new() as ArenaWorld
	arena.title = "LAN BRAWL"
	var loaded_map := BrawlMapCatalog.load_definition(str(NetworkSession.match_config.get("map_id", "")))
	if loaded_map == null or loaded_map.map_version != int(NetworkSession.match_config.get("map_version", 0)):
		NetworkSession.close_session("地图数据缺失或版本不一致。")
		get_tree().change_scene_to_file.bind("res://scenes/launcher.tscn").call_deferred()
		return
	arena.configure(loaded_map)
	add_child(arena)
	command_stream = BattleCommandStream.new()
	command_stream.name = "NetworkBattleCommandStream"
	add_child(command_stream)
	pathfinder = ArenaPathfinder.new()
	pathfinder.configure(arena.map_definition.playable_bounds(0.25), arena.navigation_obstacles)
	command_runtime = BattleCommandRuntime.new()
	command_runtime.name = "NetworkBattleCommandRuntime"
	add_child(command_runtime)
	command_runtime.setup(command_stream, pathfinder)
	command_runtime.running = false
	if NetworkSession.is_host():
		battle_rng = BattleRng.new(int(NetworkSession.match_config.get("seed", 0)))
		respawn_manager = RespawnManagerScript.new() as BrawlRespawnManager
		respawn_manager.name = "BrawlRespawnManager"
		add_child(respawn_manager)
		respawn_manager.setup(arena.map_definition, battle_rng, match_authority)
		respawn_manager.respawn_scheduled.connect(_on_respawn_scheduled)
		respawn_manager.actor_respawned.connect(_on_actor_respawned)
		score_manager = ScoreManagerScript.new() as BrawlScoreManager
		score_manager.name = "BrawlScoreManager"
		add_child(score_manager)
		score_manager.setup(match_authority)
	_spawn_participants()
	arena.set_camera_target(local_actor)
	command_gateway = GatewayScript.new() as NetworkCommandGateway
	command_gateway.name = "NetworkCommandGateway"
	add_child(command_gateway)
	command_gateway.setup(NetworkSession, command_stream, command_runtime, false)
	player_controller = MobaPlayerController.new()
	player_controller.name = "NetworkPlayerController"
	add_child(player_controller)
	player_controller.setup(local_actor, arena, command_gateway, false)
	player_controller.set_process_unhandled_input(false)
	move_indicator = MoveIndicatorScript.new() as MoveDestinationIndicator
	move_indicator.name = "MoveDestinationIndicator"
	add_child(move_indicator)
	move_indicator.setup(local_actor)
	targeting_preview = TargetingPreviewScript.new() as AbilityTargetingPreview
	targeting_preview.name = "AbilityTargetingPreview"
	add_child(targeting_preview)
	targeting_preview.setup(local_actor, player_controller)
	var opponent := _first_remote_actor()
	hud = HUDScript.new() as BattleHUD
	hud.name = "NetworkBattleHUD"
	add_child(hud)
	hud.setup(local_actor, opponent)
	hud.set_respawn_mode(true)
	hud.set_top_status_visible(false)
	hud.return_to_menu_requested.connect(_leave_match)
	scoreboard = ScoreboardScript.new() as BrawlScoreboard
	scoreboard.name = "BrawlScoreboard"
	add_child(scoreboard)
	scoreboard.setup(local_actor.battle_id, NetworkSession.match_config.get("participants", []) as Array)
	player_controller.targeting_changed.connect(hud.set_targeting)
	player_controller.movement_requested.connect(_on_local_movement_requested)
	command_runtime.movement_destination_resolved.connect(_on_movement_destination_resolved)
	command_runtime.command_processed.connect(_on_command_processed)
	command_gateway.command_confirmed.connect(_on_command_confirmed)
	NetworkSession.state_snapshot_received.connect(_on_state_snapshot)
	NetworkSession.match_state_received.connect(_on_match_state)
	NetworkSession.authoritative_event_received.connect(_on_authoritative_event_received)
	NetworkSession.entity_snapshot_received.connect(_on_entity_snapshot)
	_build_ui()
	NetworkSession.match_began.connect(_on_match_began)
	NetworkSession.lobby_changed.connect(_on_lobby_changed)
	NetworkSession.state_changed.connect(_on_state_changed)
	NetworkSession.report_match_loaded.call_deferred()


func _physics_process(delta: float) -> void:
	if NetworkSession.state != BrawlNetworkSession.State.IN_MATCH or not NetworkSession.is_host() or command_stream == null:
		return
	NetworkSession.authority_tick = command_stream.current_tick
	if match_authority != null:
		match_authority.authority_tick = command_stream.current_tick
	snapshot_elapsed += delta
	if snapshot_elapsed >= SNAPSHOT_INTERVAL:
		snapshot_elapsed = fmod(snapshot_elapsed, SNAPSHOT_INTERVAL)
		for snapshot in _build_state_snapshots():
			NetworkSession.broadcast_state_snapshot(snapshot)
		NetworkSession.broadcast_entity_snapshot(_build_entity_snapshot())
	match_state_elapsed += delta
	if match_state_elapsed >= MATCH_STATE_INTERVAL:
		match_state_elapsed = fmod(match_state_elapsed, MATCH_STATE_INTERVAL)
		_broadcast_match_state()


func _process(_delta: float) -> void:
	if diagnostics_label == null or not diagnostics_panel.visible:
		return
	if NetworkSession.is_host():
		diagnostics_label.text = "房主权威端\nTick %d　命令序列 %d\n实体 %d　玩家 %d" % [
			NetworkSession.authority_tick,
			NetworkSession.latest_server_command_sequence(),
			match_authority.entity_descriptors.size() if match_authority != null else 0,
			actors_by_id.size(),
		]
	elif match_replica != null:
		diagnostics_label.text = "客户端只读副本\n丢弃旧包　角色 %d　实体 %d　事件 %d\n快照补建 %d　补删 %d　当前实体 %d" % [
			match_replica.stale_actor_snapshot_count,
			match_replica.stale_entity_snapshot_count,
			match_replica.stale_authoritative_event_count,
			match_replica.recovered_entity_spawn_count,
			match_replica.recovered_entity_remove_count,
			match_replica.entities_by_id.size(),
		]


func _spawn_participants() -> void:
	for participant_value in NetworkSession.match_config.get("participants", []):
		var participant := participant_value as Dictionary
		var peer_id := int(participant.get("peer_id", 0))
		if actors_by_peer.has(peer_id):
			continue
		var actor := ActorScript.new() as CombatActor
		actor.name = "NetworkActor_%d" % int(participant.get("actor_id", 0))
		add_child(actor)
		var definition := HeroCatalog.create(str(participant.get("hero_id", "cheems_samurai")))
		var relation := CombatActor.Relation.SELF if peer_id == NetworkSession.local_peer_id() else CombatActor.Relation.ENEMY
		actor.setup(definition, int(participant.get("player_id", 0)), str(participant.get("display_name", "玩家")), relation)
		actor.battle_id = int(participant.get("actor_id", 0))
		actor.reset_runtime(Vector3(float(participant.get("spawn_x", 0.0)), 0.05, float(participant.get("spawn_z", 0.0))))
		actor.facing = Vector3.LEFT if actor.global_position.x > 0.0 else Vector3.RIGHT
		actors_by_peer[peer_id] = actor
		actors_by_id[actor.battle_id] = actor
		if NetworkSession.is_host():
			command_runtime.register_actor(actor)
			match_authority.register_entity(actor, &"actor", actor.battle_id, actor.authoritative_actor_state())
			respawn_manager.register_actor(actor, str(participant.get("spawn_id", "")))
			score_manager.register_actor(actor)
		else:
			match_replica.register_actor(actor)
		if peer_id == NetworkSession.local_peer_id():
			local_actor = actor


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	diagnostics_panel = PanelContainer.new()
	diagnostics_panel.position = Vector2(18.0, 430.0)
	diagnostics_panel.size = Vector2(430.0, 210.0)
	diagnostics_panel.visible = false
	var diagnostics_style := StyleBoxFlat.new()
	diagnostics_style.bg_color = Color(0.025, 0.045, 0.065, 0.82)
	diagnostics_style.border_color = Color(0.36, 0.65, 0.78, 0.55)
	diagnostics_style.set_border_width_all(1)
	diagnostics_style.set_corner_radius_all(8)
	diagnostics_panel.add_theme_stylebox_override("panel", diagnostics_style)
	layer.add_child(diagnostics_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	diagnostics_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var title := Label.new()
	title.text = "局域网战斗 · 联机诊断"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("e1edf3"))
	column.add_child(title)
	status_label = Label.new()
	status_label.text = "已加载 %s，等待其他玩家…" % arena.map_definition.display_name
	status_label.add_theme_color_override("font_color", Color("8fd8ff"))
	column.add_child(status_label)
	roster_label = Label.new()
	roster_label.add_theme_color_override("font_color", Color("c8d5df"))
	column.add_child(roster_label)
	network_label = Label.new()
	network_label.text = "等待权威命令"
	network_label.add_theme_color_override("font_color", Color("92a8b8"))
	column.add_child(network_label)
	var separator := HSeparator.new()
	separator.modulate = Color(0.5, 0.7, 0.8, 0.42)
	column.add_child(separator)
	diagnostics_label = Label.new()
	diagnostics_label.text = "联机诊断准备中…"
	diagnostics_label.add_theme_color_override("font_color", Color("b9d8e8"))
	diagnostics_label.add_theme_constant_override("outline_size", 2)
	diagnostics_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	column.add_child(diagnostics_label)
	_refresh_roster(NetworkSession.roster())


func _on_match_began() -> void:
	if match_running:
		return
	match_running = true
	command_stream.reset()
	command_runtime.stop_all()
	command_runtime.running = NetworkSession.is_host()
	command_gateway.set_accepting_commands(true)
	player_controller.set_process_unhandled_input(true)
	if score_manager != null:
		score_manager.start_match()
		var initial_match_state := _build_match_state_packet()
		scoreboard.apply_match_state(initial_match_state)
		NetworkSession.broadcast_match_state(initial_match_state)
	status_label.text = "房主权威战斗已开始" if NetworkSession.is_host() else "只读战斗副本已开始"
	status_label.add_theme_color_override("font_color", Color("8ff0a4"))


func _on_state_changed(value: BrawlNetworkSession.State) -> void:
	if value == BrawlNetworkSession.State.IN_MATCH:
		_on_match_began()


func _on_lobby_changed(roster: Array) -> void:
	_refresh_roster(roster)
	var connected_peers: Dictionary = {}
	for player_value in roster:
		connected_peers[int((player_value as Dictionary).get("peer_id", 0))] = true
	for peer_id_value in actors_by_peer.keys():
		if not connected_peers.has(int(peer_id_value)):
			var actor := actors_by_peer[peer_id_value] as CombatActor
			if is_instance_valid(actor):
				if NetworkSession.is_host():
					if respawn_manager != null:
						respawn_manager.unregister_actor(actor.battle_id)
					if score_manager != null:
						score_manager.unregister_actor(actor.battle_id)
					command_runtime.unregister_actor(actor.battle_id)
				elif match_replica != null:
					match_replica.unregister_actor(actor.battle_id)
				actors_by_id.erase(actor.battle_id)
				actor.queue_free()
			actors_by_peer.erase(peer_id_value)


func _refresh_roster(roster: Array) -> void:
	if roster_label == null:
		return
	var names: Array[String] = []
	for player_value in roster:
		var player := player_value as Dictionary
		names.append("%s（%s）" % [str(player.get("display_name", "玩家")), HeroCatalog.display_name(str(player.get("hero_id", "")))])
	roster_label.text = "在线：%s" % "、".join(names)


func _on_movement_destination_resolved(actor_id: int, requested: Vector3, resolved: Vector3, reachable: bool) -> void:
	if local_actor != null and actor_id == local_actor.battle_id:
		move_indicator.show_destination(requested, resolved, reachable)


func _on_local_movement_requested(requested: Vector3) -> void:
	# Clients deliberately do not run the authority's command motor. Compute a
	# read-only preview here; the host remains authoritative for real movement.
	if NetworkSession.is_host() or local_actor == null or pathfinder == null:
		return
	var preview_path := pathfinder.find_path(local_actor.global_position, requested)
	var reachable := not preview_path.is_empty()
	var resolved := preview_path[preview_path.size() - 1] if reachable else requested
	move_indicator.show_destination(requested, resolved, reachable)


func _on_command_processed(command: BattleCommand, accepted: bool) -> void:
	if local_actor == null or command.actor_id != local_actor.battle_id:
		return
	if accepted and command.type != BattleCommand.Type.MOVE_TO:
		move_indicator.clear_destination(true)


func _on_command_confirmed(_client_sequence: int, accepted: bool, reason: String, server_sequence: int) -> void:
	if accepted:
		network_label.text = "服务器已确认操作 #%d" % server_sequence
		network_label.add_theme_color_override("font_color", Color("8fd8ff"))
	else:
		network_label.text = "操作被拒绝：%s" % reason
		network_label.add_theme_color_override("font_color", Color("ff9b8c"))
		move_indicator.clear_destination(true)


func _on_respawn_scheduled(actor: CombatActor, _duration: float) -> void:
	var motor := command_runtime.motors.get(actor.battle_id) as CommandMotor
	if motor != null:
		motor.force_cleanup_continuous_ability()
		motor.stop()
	if actor == local_actor:
		move_indicator.clear_destination()
		targeting_preview.clear()


func _on_actor_respawned(actor: CombatActor, _spawn_point_id: String) -> void:
	var motor := command_runtime.motors.get(actor.battle_id) as CommandMotor
	if motor != null:
		motor.stop()
	if actor == local_actor:
		move_indicator.clear_destination()
		targeting_preview.clear()
		arena.set_camera_target(local_actor, true)


func _build_state_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var actor_ids: Array = actors_by_id.keys()
	actor_ids.sort()
	for actor_id_value in actor_ids:
		var actor := actors_by_id[actor_id_value] as CombatActor
		if not is_instance_valid(actor):
			continue
		snapshots.append({
			"match_id": int(NetworkSession.match_config.get("match_id", 0)),
			"server_tick": command_stream.current_tick,
			"server_sequence": NetworkSession.latest_server_command_sequence(),
			"actor": actor.network_state_packet(),
		})
	return snapshots


func _broadcast_match_state() -> void:
	if score_manager == null:
		return
	var match_state := _build_match_state_packet()
	if scoreboard != null:
		scoreboard.apply_match_state(match_state)
	NetworkSession.broadcast_match_state(match_state)


func _build_match_state_packet() -> Dictionary:
	if score_manager == null:
		return {}
	var packet := score_manager.network_state_packet()
	var quality: Array[Dictionary] = []
	for value in NetworkSession.match_config.get("participants", []):
		var participant := value as Dictionary
		quality.append({
			"actor_id": int(participant.get("actor_id", 0)),
			"latency_ms": NetworkSession.peer_round_trip_time_ms(int(participant.get("peer_id", 0))),
		})
	packet["network_quality"] = quality
	return packet


func _on_state_snapshot(snapshot: Dictionary) -> void:
	if NetworkSession.is_host() or match_replica == null:
		return
	NetworkSession.authority_tick = maxi(NetworkSession.authority_tick, int(snapshot.get("server_tick", 0)))
	if snapshot.has("match_state"):
		var match_state := snapshot.get("match_state", {}) as Dictionary
		scoreboard.apply_match_state(match_state)
		if bool(match_state.get("ended", false)):
			_end_local_match()
		return
	var actor_packet := snapshot.get("actor", {}) as Dictionary
	var is_local_snapshot := local_actor != null and int(actor_packet.get("actor_id", 0)) == local_actor.battle_id
	var was_defeated := is_local_snapshot and local_actor.is_defeated
	if match_replica.apply_actor_snapshot(snapshot) and was_defeated and not local_actor.is_defeated:
		arena.set_camera_target(local_actor, true)
		move_indicator.clear_destination()
		targeting_preview.clear()


func _on_match_state(match_state: Dictionary) -> void:
	if NetworkSession.is_host() or scoreboard == null:
		return
	scoreboard.apply_match_state(match_state)
	if bool(match_state.get("ended", false)):
		_end_local_match()


func _on_authoritative_event_received(event_envelope: Dictionary) -> void:
	if NetworkSession.is_host() or match_replica == null:
		return
	match_replica.apply_authoritative_event(event_envelope)


func _on_entity_snapshot(snapshot: Dictionary) -> void:
	if NetworkSession.is_host() or match_replica == null:
		return
	NetworkSession.authority_tick = maxi(NetworkSession.authority_tick, int(snapshot.get("server_tick", 0)))
	match_replica.apply_entity_snapshot(snapshot)


func _on_authoritative_event_emitted(event: AuthoritativeEvent) -> void:
	if not NetworkSession.is_host() or not _is_supported_network_event(event):
		return
	var event_packet := event.to_packet()
	if event.event_type == AuthoritativeEvent.MATCH_RULE and str(event.payload.get("event_kind", "")) in ["kill_announcement", "match_ended"]:
		var payload := event_packet.get("payload", {}) as Dictionary
		payload["state"] = _build_match_state_packet()
		event_packet["payload"] = payload
	NetworkSession.broadcast_authoritative_event({
		"match_id": int(NetworkSession.match_config.get("match_id", 0)),
		"event": event_packet,
	})


func _build_entity_snapshot() -> Dictionary:
	var entities: Array[Dictionary] = []
	if match_authority != null:
		for value in match_authority.state_digest().get("entities", []):
			if value is Dictionary and _is_supported_network_entity(value as Dictionary):
				entities.append((value as Dictionary).duplicate(true))
	return {
		"match_id": int(NetworkSession.match_config.get("match_id", 0)),
		"server_tick": command_stream.current_tick,
		"last_event_id": match_authority.next_event_id - 1 if match_authority != null else 0,
		"entities": entities,
	}


func _is_supported_network_event(event: AuthoritativeEvent) -> bool:
	if event == null:
		return false
	if event.event_type == AuthoritativeEvent.WORLD_EFFECT:
		return str(event.payload.get("vfx_id", "")) == "chu_ying_board"
	if event.event_type == AuthoritativeEvent.HERO_EFFECT:
		return str(event.payload.get("vfx_id", "")) in [
			"ability_vfx",
			"chu_ying_teleport_charge", "chu_ying_teleport",
			"sword_shield_transform",
			"sword_shield_block",
			"cheems_dimensional_focus", "cheems_dimensional_circle", "cheems_dimensional_cancel", "cheems_dimensional_cut", "cheems_multi_slash",
			"bear_poison_mark", "bear_poison_burst", "bear_backstab", "bear_ambush", "bear_grapple_pull",
			"nailoong_bounce", "nailoong_takeoff", "nailoong_landing", "nailoong_heal_tick",
		]
	if event.event_type == AuthoritativeEvent.MATCH_RULE:
		return str(event.payload.get("event_kind", "")) in ["respawn_scheduled", "actor_respawned", "kill_announcement", "match_ended"]
	if event.event_type == AuthoritativeEvent.COMBAT_FEEDBACK:
		return str(event.payload.get("kind", "")) in ["damage", "heal"]
	if event.event_type == AuthoritativeEvent.ENTITY_SPAWNED:
		return str(event.payload.get("entity_kind", "")) in ["projectile", "delayed_attack", "chu_ying_stone", "chu_ying_barrier"]
	if event.event_type == AuthoritativeEvent.ENTITY_DESTROYED:
		return str(event.payload.get("entity_kind", "")) in ["projectile", "delayed_attack", "chu_ying_stone", "chu_ying_barrier"]
	return false


func _is_supported_network_entity(snapshot: Dictionary) -> bool:
	return str(snapshot.get("entity_kind", "")) in ["projectile", "delayed_attack", "chu_ying_stone", "chu_ying_barrier"]


func _on_authority_event_consumed(event: AuthoritativeEvent) -> void:
	if event == null or event.event_type != AuthoritativeEvent.MATCH_RULE or scoreboard == null:
		return
	var event_kind := str(event.payload.get("event_kind", ""))
	if event_kind == "kill_announcement":
		scoreboard.show_kill_announcement(event.payload)
	elif event_kind == "match_ended":
		scoreboard.show_results(event.payload)
		_end_local_match()


func _end_local_match() -> void:
	if not match_running:
		return
	match_running = false
	player_controller.set_process_unhandled_input(false)
	command_runtime.running = false
	command_runtime.stop_all()
	command_gateway.set_accepting_commands(false)
	if respawn_manager != null:
		respawn_manager.running = false


func _first_remote_actor() -> CombatActor:
	for peer_id_value in actors_by_peer.keys():
		if int(peer_id_value) != NetworkSession.local_peer_id():
			return actors_by_peer[peer_id_value] as CombatActor
	return local_actor


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F3:
		get_viewport().set_input_as_handled()
		if diagnostics_panel != null:
			diagnostics_panel.visible = not diagnostics_panel.visible
	elif event.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		_leave_match()


func _leave_match() -> void:
	if leaving:
		return
	leaving = true
	player_controller.set_process_unhandled_input(false)
	command_runtime.running = false
	command_gateway.set_accepting_commands(false)
	command_runtime.shutdown_all()
	NetworkSession.close_session()
	get_tree().change_scene_to_file.bind("res://scenes/launcher.tscn").call_deferred()
