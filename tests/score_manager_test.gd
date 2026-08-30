extends SceneTree

var failures: Array[String] = []
var kill_events: Array[Dictionary] = []
var finish_events: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var authority := MatchAuthority.new()
	root.add_child(authority)
	var manager := BrawlScoreManager.new()
	root.add_child(manager)
	manager.setup(authority, 300.0, 10)
	manager.kill_recorded.connect(func(payload: Dictionary) -> void: kill_events.append(payload.duplicate(true)))
	manager.match_finished.connect(func(payload: Dictionary) -> void: finish_events.append(payload.duplicate(true)))

	var killer := _actor(1, "甲")
	var victim := _actor(2, "乙")
	var helper := _actor(3, "丙")
	manager.register_actor(killer)
	manager.register_actor(victim)
	manager.register_actor(helper)
	manager.start_match()
	killer.hp = 50.0
	_check(is_equal_approx(killer.heal(17.0, killer.battle_id), 17.0), "actual self-healing should be accepted")
	_check(is_equal_approx(float(_stat(manager.network_state_packet(), 1).get("healing", 0.0)), 17.0), "score state should record actual healing by source")

	var attack := killer.ability_by_id("basic")
	_check(victim.receive_hit(helper, attack, Vector3.RIGHT, 1, 5.0), "assist damage should be accepted")
	_check(victim.receive_hit(killer, attack, Vector3.RIGHT, 2, 9999.0), "lethal damage should be accepted")
	var state := manager.network_state_packet()
	_check(_stat(state, 1).get("kills", 0) == 1, "lethal source should receive the kill")
	_check(_stat(state, 2).get("deaths", 0) == 1, "victim should receive one death")
	_check(_stat(state, 3).get("assists", 0) == 1, "recent non-lethal contributor should receive an assist")
	_check(is_equal_approx(float(_stat(state, 2).get("damage_taken", 0.0)), victim.definition.max_hp), "damage taken should count actual health lost, not overkill")
	_check(str(kill_events[0].get("phrase", "")) == "卧龙出山", "first streak phrase should match the requested announcement")

	for attack_id in [3, 4]:
		victim.reset_runtime(Vector3.ZERO)
		victim.receive_hit(killer, attack, Vector3.RIGHT, attack_id, 9999.0)
	_check(str(kill_events[1].get("phrase", "")) == "一战成名", "second streak phrase should use the requested double-kill wording")
	_check(int(_stat(manager.network_state_packet(), 1).get("streak", 0)) == 3, "three uninterrupted kills should build a three-kill streak")
	killer.reset_runtime(Vector3.ZERO)
	killer.receive_hit(helper, attack, Vector3.LEFT, 5, 9999.0)
	var shutdown := kill_events.back() as Dictionary
	_check(bool(shutdown.get("shutdown", false)), "killing a player on a three-kill streak should be a shutdown")
	_check(str(shutdown.get("announcement", "")).contains("终结"), "shutdown text should override the ordinary streak phrase")
	_check(int(_stat(manager.network_state_packet(), 1).get("streak", -1)) == 0, "death should reset the victim's streak")

	manager.finish_match("test")
	_check(finish_events.size() == 1 and manager.ended, "the authority should finish a match exactly once")
	_check(_event_count(authority, "kill_announcement") == 4, "every kill should emit one reliable global announcement")
	_check(_event_count(authority, "match_ended") == 1, "match end should emit one reliable rule event")

	if failures.is_empty():
		print("KDA, assists, damage totals, streak announcements, shutdown, and match result checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _actor(actor_id: int, actor_name: String) -> CombatActor:
	var actor := CombatActor.new()
	root.add_child(actor)
	actor.setup(PlaceholderHero.create(), actor_id, actor_name, CombatActor.Relation.ENEMY)
	actor.battle_id = actor_id
	actor.reset_runtime(Vector3.ZERO)
	return actor


func _stat(state: Dictionary, actor_id: int) -> Dictionary:
	for value in state.get("stats", []):
		var row := value as Dictionary
		if int(row.get("actor_id", 0)) == actor_id:
			return row
	return {}


func _event_count(authority: MatchAuthority, kind: String) -> int:
	var count := 0
	for event in authority.event_log:
		if event.event_type == AuthoritativeEvent.MATCH_RULE and str(event.payload.get("event_kind", "")) == kind:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
