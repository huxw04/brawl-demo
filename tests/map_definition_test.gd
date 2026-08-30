extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var test_map := BrawlMapCatalog.default_test_map()
	var brawl_map := BrawlMapCatalog.default_network_map()
	_check(test_map != null, "the test map should load from JSON")
	_check(brawl_map != null, "the brawl map should load from JSON")
	if test_map != null:
		_check(test_map.size.is_equal_approx(Vector2(14.0, 9.0)), "the migrated test map should preserve its dimensions")
		_check(test_map.navigation_obstacles().size() == 2, "the migrated test map should preserve both walls")
		_check(test_map.spawn_position(0).is_equal_approx(Vector3(-4.6, 0.05, 1.4)), "spawn lookup should preserve stable order")
	if brawl_map != null:
		_check(brawl_map.map_id == BrawlMapCatalog.LARGE_BRAWL_MAP_ID and brawl_map.map_version == 2, "the network map should expose a stable id and version")
		_check(brawl_map.size.is_equal_approx(Vector2(30.0, 22.0)), "the network map should be 3000 by 2200 yards")
		var clamped := brawl_map.clamp_world_point(Vector3(100.0, 0.0, -100.0))
		_check(brawl_map.playable_bounds().has_point(Vector2(clamped.x, clamped.z)), "map clamping should use data-defined bounds")

	_check(BrawlMapCatalog.network_map_ids().size() == 3, "the v1 catalog should contain three selectable combat maps")
	for map_id in BrawlMapCatalog.network_map_ids():
		var definition := BrawlMapCatalog.load_definition(map_id)
		_check(definition != null, "catalog map %s should load" % map_id)
		if definition == null:
			continue
		_check(definition.spawn_points.size() >= 8, "%s should provide at least eight stable respawn points" % map_id)
		var arena := ArenaWorld.new()
		arena.configure(definition)
		root.add_child(arena)
		await process_frame
		_check(arena.navigation_obstacles.size() == definition.obstacles.size(), "%s should build every data-defined obstacle" % map_id)
		var pathfinder := ArenaPathfinder.new()
		pathfinder.configure(definition.playable_bounds(0.25), arena.navigation_obstacles)
		var anchor := definition.spawn_position(0)
		for spawn in definition.spawn_points:
			var position := spawn.get("position", Vector3.ZERO) as Vector3
			_check(definition.is_open_world_point(position, 0.45), "%s spawn %s should have actor clearance" % [map_id, spawn.get("id", "")])
			_check(not pathfinder.find_path(anchor, position).is_empty(), "%s spawn %s should be reachable from the first spawn" % [map_id, spawn.get("id", "")])
		arena.queue_free()

	if failures.is_empty():
		print("Map definition, construction, and dynamic navigation checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
