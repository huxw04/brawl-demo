extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stream := BattleCommandStream.new()
	root.add_child(stream)
	var first := BattleCommand.create(1, BattleCommand.Type.MOVE_TO, Vector3(2.0, 0.0, 3.0))
	var second := BattleCommand.create(1, BattleCommand.Type.JUMP)
	stream.submit(first)
	stream.submit(second)
	var tick_commands := stream.advance_tick()
	_check(tick_commands.size() == 2, "commands for the same tick should drain together")
	_check(tick_commands[0].sequence < tick_commands[1].sequence, "commands should retain sequence order")
	var encoded := first.to_packet()
	var decoded := BattleCommand.from_packet(encoded)
	_check(decoded.actor_id == first.actor_id and decoded.world_target.is_equal_approx(first.world_target), "command serialization should round-trip")

	var rng_a := BattleRng.new(424242)
	var rng_b := BattleRng.new(424242)
	for _index in range(16):
		_check(is_equal_approx(rng_a.randf_value(), rng_b.randf_value()), "equal seeds should produce equal local RNG streams")
	_check(rng_a.draws == 16, "RNG should track draw count")

	var pathfinder := ArenaPathfinder.new()
	pathfinder.configure([Rect2(Vector2(-0.5, -0.65), Vector2(1.0, 1.3))])
	var path := pathfinder.find_path(Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0))
	_check(path.size() > 2, "A* should find a path around a wall")
	var deviates_around_wall := false
	for point in path:
		if absf(point.z) > 1.0:
			deviates_around_wall = true
	_check(deviates_around_wall, "A* path should leave the blocked straight line")

	var arena := ArenaWorld.new()
	arena.include_test_walls = false
	root.add_child(arena)
	var hero := CombatActor.new()
	root.add_child(hero)
	hero.setup(CheemsSamurai.create(), 1, "cheems", CombatActor.Relation.SELF)
	hero.global_position = Vector3(-5.0, 0.05, 0.0)
	var target := CombatActor.new()
	root.add_child(target)
	target.setup(PlaceholderHero.create(), 2, "target", CombatActor.Relation.ENEMY)
	target.global_position = Vector3(-0.5, 0.05, 0.0)
	await physics_frame
	var attack_pathfinder := ArenaPathfinder.new()
	var no_obstacles: Array[Rect2] = []
	attack_pathfinder.configure(no_obstacles)
	var motor := CommandMotor.new()
	root.add_child(motor)
	motor.setup(hero, attack_pathfinder)
	motor.apply_command(BattleCommand.create(1, BattleCommand.Type.BASIC_ATTACK, target.global_position))
	_check(motor.pending_basic and hero.current_ability == null, "out-of-range basic should be buffered instead of firing immediately")
	for _frame in range(150):
		motor.advance_movement()
		await physics_frame
	_check(not motor.pending_basic, "buffered basic should clear after reaching acquisition range")
	_check(target.hp < target.definition.max_hp, "buffered basic should execute and damage after pathing into range")
	motor.queue_free()
	hero.queue_free()
	target.queue_free()
	arena.queue_free()

	stream.queue_free()
	if failures.is_empty():
		print("Command, RNG, and pathfinding checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
