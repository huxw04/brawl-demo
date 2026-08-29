class_name ArenaPathfinder
extends RefCounted

const CELL_SIZE := 0.25
const CLEARANCE := 0.42

var grid := AStarGrid2D.new()
var navigation_bounds := Rect2(Vector2(-6.75, -4.25), Vector2(13.5, 8.5))
var grid_width := 55
var grid_height := 35


func configure(bounds_or_obstacles: Variant, obstacles: Array[Rect2] = []) -> void:
	# The one-argument form remains available to focused unit tests. Runtime
	# scenes always pass their loaded map bounds explicitly.
	if bounds_or_obstacles is Rect2:
		navigation_bounds = bounds_or_obstacles as Rect2
	else:
		var test_map := BrawlMapCatalog.default_test_map()
		if test_map != null:
			navigation_bounds = test_map.playable_bounds(0.25)
		obstacles.clear()
		if bounds_or_obstacles is Array:
			for obstacle_value in bounds_or_obstacles as Array:
				if obstacle_value is Rect2:
					obstacles.append(obstacle_value as Rect2)
	grid_width = maxi(2, ceili(navigation_bounds.size.x / CELL_SIZE) + 1)
	grid_height = maxi(2, ceili(navigation_bounds.size.y / CELL_SIZE) + 1)
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, grid_width, grid_height)
	grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	grid.offset = navigation_bounds.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for obstacle in obstacles:
		_mark_obstacle(obstacle.grow(CLEARANCE))


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start_id := _world_to_id(from)
	var end_id := _world_to_id(to)
	if grid.is_point_solid(start_id):
		start_id = _nearest_open(start_id)
	var ids: Array[Vector2i] = grid.get_id_path(start_id, end_id, true)
	var result := PackedVector3Array()
	for id in ids:
		var point := grid.get_point_position(id)
		result.append(Vector3(point.x, 0.0, point.y))
	if not ids.is_empty() and not grid.is_point_solid(end_id):
		result.append(Vector3(clampf(to.x, navigation_bounds.position.x, navigation_bounds.end.x), 0.0, clampf(to.z, navigation_bounds.position.y, navigation_bounds.end.y)))
	return result


func _mark_obstacle(rect: Rect2) -> void:
	var from_id := _world_to_id(Vector3(rect.position.x, 0.0, rect.position.y))
	var to_id := _world_to_id(Vector3(rect.end.x, 0.0, rect.end.y))
	for x in range(from_id.x, to_id.x + 1):
		for y in range(from_id.y, to_id.y + 1):
			var id := Vector2i(x, y)
			if grid.is_in_boundsv(id):
				grid.set_point_solid(id, true)


func _world_to_id(point: Vector3) -> Vector2i:
	return Vector2i(
		clampi(roundi((point.x - navigation_bounds.position.x) / CELL_SIZE), 0, grid_width - 1),
		clampi(roundi((point.z - navigation_bounds.position.y) / CELL_SIZE), 0, grid_height - 1),
	)


func _nearest_open(origin: Vector2i) -> Vector2i:
	for radius in range(1, 6):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				var candidate := Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return origin
