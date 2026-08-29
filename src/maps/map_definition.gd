class_name BrawlMapDefinition
extends RefCounted

const FORMAT_VERSION := 1

var map_id := ""
var map_version := 0
var display_name := ""
var size := Vector2.ZERO
var floor_color := Color("263546")
var grid_color := Color("3b4d60")
var boundary_color := Color("526b80")
var camera_size := 11.5
var camera_position := Vector3(0.0, 10.8, 11.8)
var camera_look_at := Vector3(0.0, 0.7, 0.0)
var spawn_points: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []


static func load_from_file(path: String) -> BrawlMapDefinition:
	if not FileAccess.file_exists(path):
		push_error("Map file does not exist: %s" % path)
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Map file is not a JSON object: %s" % path)
		return null
	var definition := BrawlMapDefinition.new()
	if not definition._read(parsed as Dictionary):
		push_error("Invalid map definition: %s" % path)
		return null
	return definition


func _read(data: Dictionary) -> bool:
	if int(data.get("format_version", 0)) != FORMAT_VERSION:
		return false
	map_id = str(data.get("map_id", "")).strip_edges()
	map_version = int(data.get("map_version", 0))
	display_name = str(data.get("display_name", map_id)).strip_edges()
	size = _vector2(data.get("size", []))
	floor_color = Color.from_string(str(data.get("floor_color", "263546")), Color("263546"))
	grid_color = Color.from_string(str(data.get("grid_color", "3b4d60")), Color("3b4d60"))
	boundary_color = Color.from_string(str(data.get("boundary_color", "526b80")), Color("526b80"))
	if not data.get("camera", {}) is Dictionary or not data.get("spawn_points", []) is Array or not data.get("obstacles", []) is Array:
		return false
	var camera_data := data.get("camera", {}) as Dictionary
	camera_size = float(camera_data.get("orthographic_size", 11.5))
	camera_position = _vector3(camera_data.get("position", []), Vector3(0.0, 10.8, 11.8))
	camera_look_at = _vector3(camera_data.get("look_at", []), Vector3(0.0, 0.7, 0.0))
	spawn_points.clear()
	for value in data.get("spawn_points", []):
		if value is Dictionary:
			var source := value as Dictionary
			spawn_points.append({
				"id": str(source.get("id", "")),
				"position": _vector3(source.get("position", []), Vector3.ZERO),
			})
	obstacles.clear()
	for value in data.get("obstacles", []):
		if value is Dictionary:
			var source := value as Dictionary
			obstacles.append({
				"id": str(source.get("id", "")),
				"kind": str(source.get("kind", "box")),
				"center": _vector3(source.get("center", []), Vector3.ZERO),
				"size": _vector3(source.get("size", []), Vector3.ZERO),
				"color": Color.from_string(str(source.get("color", "755b89")), Color("755b89")),
				"label": str(source.get("label", "")),
			})
	return _validate()


func _validate() -> bool:
	if map_id.is_empty() or map_version < 1 or size.x < 4.0 or size.y < 4.0 or camera_size <= 0.0:
		return false
	var ids := {}
	var bounds := playable_bounds(0.2)
	for spawn in spawn_points:
		var spawn_id := str(spawn.get("id", ""))
		var position := spawn.get("position", Vector3.ZERO) as Vector3
		if spawn_id.is_empty() or ids.has(spawn_id) or not bounds.has_point(Vector2(position.x, position.z)):
			return false
		ids[spawn_id] = true
	if spawn_points.size() < 2:
		return false
	ids.clear()
	for obstacle in obstacles:
		var obstacle_id := str(obstacle.get("id", ""))
		var center := obstacle.get("center", Vector3.ZERO) as Vector3
		var obstacle_size := obstacle.get("size", Vector3.ZERO) as Vector3
		if obstacle_id.is_empty() or ids.has(obstacle_id) or str(obstacle.get("kind", "")) != "box":
			return false
		if obstacle_size.x <= 0.0 or obstacle_size.y <= 0.0 or obstacle_size.z <= 0.0:
			return false
		var half_size := Vector2(obstacle_size.x, obstacle_size.z) * 0.5
		var minimum := Vector2(center.x, center.z) - half_size
		var maximum := Vector2(center.x, center.z) + half_size
		if minimum.x < -size.x * 0.5 or minimum.y < -size.y * 0.5 or maximum.x > size.x * 0.5 or maximum.y > size.y * 0.5:
			return false
		ids[obstacle_id] = true
	return true


func playable_bounds(margin := 0.3) -> Rect2:
	var half := size * 0.5
	return Rect2(Vector2(-half.x + margin, -half.y + margin), size - Vector2.ONE * margin * 2.0)


func clamp_world_point(point: Vector3, margin := 0.3) -> Vector3:
	var bounds := playable_bounds(margin)
	var inner_end := bounds.end - Vector2(0.0001, 0.0001)
	return Vector3(
		clampf(point.x, bounds.position.x, inner_end.x),
		point.y,
		clampf(point.z, bounds.position.y, inner_end.y),
	)


func spawn_position(index: int) -> Vector3:
	if spawn_points.is_empty():
		return Vector3.ZERO
	return spawn_points[posmod(index, spawn_points.size())].get("position", Vector3.ZERO) as Vector3


func navigation_obstacles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for obstacle in obstacles:
		var center := obstacle.get("center", Vector3.ZERO) as Vector3
		var obstacle_size := obstacle.get("size", Vector3.ZERO) as Vector3
		result.append(Rect2(Vector2(center.x, center.z) - Vector2(obstacle_size.x, obstacle_size.z) * 0.5, Vector2(obstacle_size.x, obstacle_size.z)))
	return result


static func _vector2(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


static func _vector3(value: Variant, fallback := Vector3.ZERO) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback
