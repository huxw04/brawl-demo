class_name BrawlScoreManager
extends Node

signal score_changed(state: Dictionary)
signal kill_recorded(payload: Dictionary)
signal match_finished(payload: Dictionary)

const DEFAULT_MATCH_DURATION := 300.0
const DEFAULT_KILL_LIMIT := 10
const ASSIST_WINDOW := 10.0
const SHUTDOWN_STREAK_THRESHOLD := 3

var match_authority: MatchAuthority
var match_duration := DEFAULT_MATCH_DURATION
var kill_limit := DEFAULT_KILL_LIMIT
var remaining_time := DEFAULT_MATCH_DURATION
var running := false
var ended := false
var winner_actor_id := 0
var end_reason := ""
var actors_by_id: Dictionary = {}
var stats_by_actor: Dictionary = {}
var recent_contributors: Dictionary = {}
var last_damage_source: Dictionary = {}


func setup(authority: MatchAuthority, duration := DEFAULT_MATCH_DURATION, p_kill_limit := DEFAULT_KILL_LIMIT) -> void:
	match_authority = authority
	match_duration = maxf(1.0, duration)
	kill_limit = maxi(1, p_kill_limit)
	remaining_time = match_duration


func register_actor(actor: CombatActor) -> void:
	if actor == null:
		return
	actors_by_id[actor.battle_id] = actor
	if not stats_by_actor.has(actor.battle_id):
		stats_by_actor[actor.battle_id] = _new_stat(actor)
	if not actor.damage_received.is_connected(_on_damage_received):
		actor.damage_received.connect(_on_damage_received)
	if not actor.defeated.is_connected(_on_actor_defeated):
		actor.defeated.connect(_on_actor_defeated)


func unregister_actor(actor_id: int) -> void:
	var actor := actors_by_id.get(actor_id) as CombatActor
	if actor != null and is_instance_valid(actor):
		if actor.damage_received.is_connected(_on_damage_received):
			actor.damage_received.disconnect(_on_damage_received)
		if actor.defeated.is_connected(_on_actor_defeated):
			actor.defeated.disconnect(_on_actor_defeated)
	actors_by_id.erase(actor_id)


func start_match() -> void:
	remaining_time = match_duration
	running = true
	ended = false
	winner_actor_id = 0
	end_reason = ""
	recent_contributors.clear()
	last_damage_source.clear()
	for actor_id_value in stats_by_actor.keys():
		var old := stats_by_actor[actor_id_value] as Dictionary
		stats_by_actor[actor_id_value] = _new_stat(actors_by_id.get(int(actor_id_value)) as CombatActor, old)
	score_changed.emit(network_state_packet())


func stop() -> void:
	running = false


func finish_match(reason := "manual") -> void:
	if ended:
		return
	_end_match(reason)


func _physics_process(delta: float) -> void:
	if not running or ended:
		return
	remaining_time = maxf(0.0, remaining_time - delta)
	if remaining_time <= 0.0:
		_end_match("time_limit")


func _on_damage_received(target: CombatActor, source_actor_id: int, amount: float) -> void:
	if not running or ended or target == null or amount <= 0.0:
		return
	var target_stat := stats_by_actor.get(target.battle_id) as Dictionary
	if target_stat != null:
		target_stat["damage_taken"] = float(target_stat.get("damage_taken", 0.0)) + amount
	if source_actor_id <= 0 or source_actor_id == target.battle_id or not stats_by_actor.has(source_actor_id):
		return
	var source_stat := stats_by_actor[source_actor_id] as Dictionary
	source_stat["damage_dealt"] = float(source_stat.get("damage_dealt", 0.0)) + amount
	var contributors := recent_contributors.get(target.battle_id, {}) as Dictionary
	contributors[source_actor_id] = match_duration - remaining_time
	recent_contributors[target.battle_id] = contributors
	last_damage_source[target.battle_id] = source_actor_id


func _on_actor_defeated(victim: CombatActor) -> void:
	if not running or ended or victim == null or not stats_by_actor.has(victim.battle_id):
		return
	var victim_stat := stats_by_actor[victim.battle_id] as Dictionary
	var victim_streak := int(victim_stat.get("streak", 0))
	victim_stat["deaths"] = int(victim_stat.get("deaths", 0)) + 1
	victim_stat["streak"] = 0
	var contributors := recent_contributors.get(victim.battle_id, {}) as Dictionary
	var killer_id := int(last_damage_source.get(victim.battle_id, 0))
	if killer_id <= 0 or not stats_by_actor.has(killer_id):
		killer_id = _latest_valid_contributor(contributors)
	var assists: Array[int] = []
	if killer_id > 0 and stats_by_actor.has(killer_id):
		var killer_stat := stats_by_actor[killer_id] as Dictionary
		killer_stat["kills"] = int(killer_stat.get("kills", 0)) + 1
		killer_stat["streak"] = int(killer_stat.get("streak", 0)) + 1
		for source_id_value in contributors.keys():
			var source_id := int(source_id_value)
			if source_id == killer_id or source_id == victim.battle_id or not stats_by_actor.has(source_id):
				continue
			if match_duration - remaining_time - float(contributors[source_id_value]) > ASSIST_WINDOW:
				continue
			var assist_stat := stats_by_actor[source_id] as Dictionary
			assist_stat["assists"] = int(assist_stat.get("assists", 0)) + 1
			assists.append(source_id)
	recent_contributors.erase(victim.battle_id)
	last_damage_source.erase(victim.battle_id)
	var shutdown := killer_id > 0 and victim_streak >= SHUTDOWN_STREAK_THRESHOLD
	var payload := _kill_payload(killer_id, victim.battle_id, assists, shutdown, victim_streak)
	kill_recorded.emit(payload)
	_emit_rule_event("kill_announcement", killer_id, payload)
	score_changed.emit(network_state_packet())
	if killer_id > 0 and int((stats_by_actor[killer_id] as Dictionary).get("kills", 0)) >= kill_limit:
		_end_match("kill_limit", killer_id)


func _latest_valid_contributor(contributors: Dictionary) -> int:
	var latest_id := 0
	var latest_mark := -INF
	for source_id_value in contributors.keys():
		var source_id := int(source_id_value)
		var mark := float(contributors[source_id_value])
		if match_duration - remaining_time - mark <= ASSIST_WINDOW and mark > latest_mark:
			latest_mark = mark
			latest_id = source_id
	return latest_id


func _kill_payload(killer_id: int, victim_id: int, assists: Array[int], shutdown: bool, victim_streak: int) -> Dictionary:
	var killer_stat := stats_by_actor.get(killer_id, {}) as Dictionary
	var victim_stat := stats_by_actor.get(victim_id, {}) as Dictionary
	var streak := int(killer_stat.get("streak", 0))
	var phrase := _streak_phrase(streak)
	var killer_name := str(killer_stat.get("name", "环境"))
	var victim_name := str(victim_stat.get("name", "玩家"))
	var announcement := "%s 终结了 %s！" % [killer_name, victim_name] if shutdown else "%s 击败 %s · %s" % [killer_name, victim_name, phrase]
	return {
		"killer_actor_id": killer_id,
		"victim_actor_id": victim_id,
		"assist_actor_ids": assists.duplicate(),
		"killer_streak": streak,
		"victim_streak": victim_streak,
		"shutdown": shutdown,
		"phrase": phrase,
		"announcement": announcement,
		"state": network_state_packet(),
	}


func _streak_phrase(streak: int) -> String:
	match streak:
		1:
			return "卧龙出山"
		2:
			return "举世成名"
		3:
			return "举世皆惊"
		4:
			return "天下无敌"
		_:
			return "诸天灭地" if streak >= 5 else ""


func _end_match(reason: String, requested_winner := 0) -> void:
	if ended:
		return
	running = false
	ended = true
	remaining_time = maxf(0.0, remaining_time)
	end_reason = reason
	winner_actor_id = requested_winner if requested_winner > 0 else _leading_actor_id()
	var payload := {
		"reason": end_reason,
		"winner_actor_id": winner_actor_id,
		"state": network_state_packet(),
	}
	match_finished.emit(payload)
	_emit_rule_event("match_ended", winner_actor_id, payload)
	score_changed.emit(network_state_packet())


func _leading_actor_id() -> int:
	var rows := _sorted_stats()
	if rows.is_empty():
		return 0
	if rows.size() > 1 and _same_result(rows[0], rows[1]):
		return 0
	return int(rows[0].get("actor_id", 0))


func _same_result(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("kills", 0)) == int(b.get("kills", 0)) \
		and int(a.get("assists", 0)) == int(b.get("assists", 0)) \
		and int(a.get("deaths", 0)) == int(b.get("deaths", 0))


func network_state_packet() -> Dictionary:
	return {
		"remaining_time": remaining_time,
		"match_duration": match_duration,
		"kill_limit": kill_limit,
		"running": running,
		"ended": ended,
		"winner_actor_id": winner_actor_id,
		"end_reason": end_reason,
		"stats": _sorted_stats(),
	}


func _sorted_stats() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for value in stats_by_actor.values():
		rows.append((value as Dictionary).duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("kills", 0)) != int(b.get("kills", 0)):
			return int(a.get("kills", 0)) > int(b.get("kills", 0))
		if int(a.get("assists", 0)) != int(b.get("assists", 0)):
			return int(a.get("assists", 0)) > int(b.get("assists", 0))
		if int(a.get("deaths", 0)) != int(b.get("deaths", 0)):
			return int(a.get("deaths", 0)) < int(b.get("deaths", 0))
		return int(a.get("actor_id", 0)) < int(b.get("actor_id", 0))
	)
	return rows


func _new_stat(actor: CombatActor, fallback: Dictionary = {}) -> Dictionary:
	return {
		"actor_id": actor.battle_id if actor != null else int(fallback.get("actor_id", 0)),
		"name": actor.actor_name if actor != null else str(fallback.get("name", "玩家")),
		"kills": 0,
		"deaths": 0,
		"assists": 0,
		"streak": 0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
	}


func _emit_rule_event(event_kind: String, entity_id: int, extra: Dictionary) -> void:
	if match_authority == null:
		return
	var payload := extra.duplicate(true)
	payload["event_kind"] = event_kind
	match_authority.emit_authoritative_event(AuthoritativeEvent.MATCH_RULE, entity_id, payload)
