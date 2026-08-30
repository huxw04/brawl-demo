extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var authority := MatchAuthority.new()
	root.add_child(authority)
	var presentation := AuthorityEventPresentation.new()
	root.add_child(presentation)
	presentation.setup(authority)
	var source := CombatActor.new()
	root.add_child(source)
	source.setup(PlaceholderHero.create(), 1, "local", CombatActor.Relation.SELF)
	source.battle_id = 1
	var target := CombatActor.new()
	root.add_child(target)
	target.setup(PlaceholderHero.create(), 2, "enemy", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	authority.register_entity(source, &"actor", source.battle_id, source.authoritative_actor_state())
	authority.register_entity(target, &"actor", target.battle_id, target.authoritative_actor_state())
	await process_frame

	var basic := source.ability_by_id("basic")
	_check(target.receive_hit(source, basic, Vector3.RIGHT, 1, 12.0), "local damage should land")
	_check(presentation.combat_feedback_event_count == 1 and presentation.combat_number_spawn_count == 1, "local damage should spawn exactly one number")
	_check(_texts().has("12"), "damage number should display actual health lost")

	source.hp = 50.0
	_check(is_equal_approx(source.heal(8.0, source.battle_id), 8.0), "central healing should return actual health restored")
	_check(presentation.combat_feedback_event_count == 2 and presentation.combat_number_spawn_count == 2, "local healing should spawn exactly one number")
	_check(_texts().has("+8"), "healing number should include a plus sign")

	var spawned_before_enemy_actions := presentation.combat_number_spawn_count
	source.receive_hit(target, target.ability_by_id("basic"), Vector3.LEFT, 2, 5.0)
	target.hp = 50.0
	target.heal(5.0, target.battle_id)
	_check(presentation.combat_feedback_event_count == 4, "authority should retain feedback for all combat results")
	_check(presentation.combat_number_spawn_count == spawned_before_enemy_actions, "other players' damage and healing should remain hidden locally")

	source.hp = source.definition.max_hp
	var event_count_before_overheal := presentation.combat_feedback_event_count
	_check(is_zero_approx(source.heal(50.0, source.battle_id)), "overheal should report zero actual healing")
	_check(presentation.combat_feedback_event_count == event_count_before_overheal, "zero actual healing should not emit a floating-number event")

	if failures.is_empty():
		print("Combat feedback and floating-number checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _texts() -> Array[String]:
	var result: Array[String] = []
	for node in get_nodes_in_group("world_combat_numbers"):
		if node is Label3D:
			result.append((node as Label3D).text)
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
