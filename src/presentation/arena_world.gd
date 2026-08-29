class_name ArenaWorld
extends Node3D

var title := "BRAWL ARENA"
var include_test_walls := true
var show_measurement_marker := false
var camera: Camera3D
var navigation_obstacles: Array[Rect2] = []
var map_definition: BrawlMapDefinition
var follow_target: Node3D
var camera_focus := Vector3.ZERO
var camera_offset := Vector3.ZERO


func configure(definition: BrawlMapDefinition, include_obstacles := true) -> void:
	map_definition = definition
	include_test_walls = include_obstacles


func _ready() -> void:
	if map_definition == null:
		map_definition = BrawlMapCatalog.default_test_map()
	if map_definition == null:
		push_error("ArenaWorld cannot load its map definition.")
		return
	_build_environment()
	_build_floor()
	_build_boundaries()
	if include_test_walls:
		_build_obstacles()
	if show_measurement_marker:
		_build_measurement_marker()


func _process(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target) or camera == null:
		return
	var target_position := map_definition.clamp_world_point(follow_target.global_position, 0.8)
	target_position.y = map_definition.camera_look_at.y
	var weight := 1.0 - exp(-8.0 * delta)
	camera_focus = camera_focus.lerp(target_position, weight)
	camera.position = camera_focus + camera_offset
	camera.look_at(camera_focus, Vector3.UP)


func set_camera_target(target: Node3D, snap := true) -> void:
	follow_target = target
	if target == null or camera == null:
		return
	var target_position := map_definition.clamp_world_point(target.global_position, 0.8)
	target_position.y = map_definition.camera_look_at.y
	if snap:
		camera_focus = target_position
		camera.position = camera_focus + camera_offset
		camera.look_at(camera_focus, Vector3.UP)


func _build_environment() -> void:
	camera = Camera3D.new()
	camera.name = "ArenaCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = map_definition.camera_size
	camera.position = map_definition.camera_position
	camera_focus = map_definition.camera_look_at
	camera_offset = camera.position - camera_focus
	camera.look_at_from_position(camera.position, camera_focus, Vector3.UP)
	camera.current = true
	add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101722")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8d5e8")
	environment.ambient_light_energy = 0.48
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func _build_floor() -> void:
	_add_static_box("Floor", Vector3(0.0, -0.12, 0.0), Vector3(map_definition.size.x, 0.24, map_definition.size.y), map_definition.floor_color, true)
	# Thin boxes form a world-space grid, so the camera projection is honest.
	var half := map_definition.size * 0.5
	for x_index in range(ceili(-half.x), floori(half.x) + 1):
		_add_visual_box(Vector3(float(x_index), 0.012, 0.0), Vector3(0.018, 0.014, map_definition.size.y), map_definition.grid_color)
	for z_index in range(ceili(-half.y), floori(half.y) + 1):
		_add_visual_box(Vector3(0.0, 0.014, float(z_index)), Vector3(map_definition.size.x, 0.016, 0.018), map_definition.grid_color)


func _build_boundaries() -> void:
	var half := map_definition.size * 0.5
	var border_color := map_definition.boundary_color
	_add_static_box("NorthBoundary", Vector3(0.0, 0.35, -half.y - 0.15), Vector3(map_definition.size.x + 0.5, 0.7, 0.3), border_color, true)
	_add_static_box("SouthBoundary", Vector3(0.0, 0.35, half.y + 0.15), Vector3(map_definition.size.x + 0.5, 0.7, 0.3), border_color, true)
	_add_static_box("WestBoundary", Vector3(-half.x - 0.15, 0.35, 0.0), Vector3(0.3, 0.7, map_definition.size.y), border_color, true)
	_add_static_box("EastBoundary", Vector3(half.x + 0.15, 0.35, 0.0), Vector3(0.3, 0.7, map_definition.size.y), border_color, true)


func _build_obstacles() -> void:
	navigation_obstacles = map_definition.navigation_obstacles()
	for obstacle in map_definition.obstacles:
		var center := obstacle.get("center", Vector3.ZERO) as Vector3
		var size := obstacle.get("size", Vector3.ZERO) as Vector3
		_add_static_box(str(obstacle.get("id", "Obstacle")).to_pascal_case(), center, size, obstacle.get("color", Color("755b89")) as Color, true)
		var label := str(obstacle.get("label", ""))
		if not label.is_empty():
			_add_wall_label(label, center + Vector3.UP * (size.y * 0.5 + 0.25))


func _add_static_box(node_name: String, center: Vector3, size: Vector3, color: Color, casts_shadow: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)
	add_child(body)
	return body


func _add_visual_box(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _add_wall_label(text: String, at_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at_position
	label.font_size = 34
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("e7d9f4")
	label.no_depth_test = true
	add_child(label)


func _build_measurement_marker() -> void:
	var bounds := map_definition.playable_bounds(0.8)
	var origin := Vector3(bounds.position.x + 0.35, 0.038, bounds.end.y - 0.35)
	_add_visual_box(origin + Vector3(0.5, 0.0, 0.0), Vector3(1.0, 0.022, 0.045), Color("8ceaff"))
	_add_visual_box(origin, Vector3(0.045, 0.032, 0.28), Color("d8f8ff"))
	_add_visual_box(origin + Vector3.RIGHT, Vector3(0.045, 0.032, 0.28), Color("d8f8ff"))
	var label := Label3D.new()
	label.text = "100码 = 1格 = 1世界单位"
	label.position = origin + Vector3(0.5, 0.08, -0.28)
	label.font_size = 30
	label.pixel_size = 0.0062
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("bcefff")
	add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func screen_to_ground(screen_position: Vector2) -> Vector3:
	if camera == null or map_definition == null:
		return Vector3.ZERO
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	var distance := -origin.y / direction.y
	var point := origin + direction * distance
	point.y = 0.0
	return map_definition.clamp_world_point(point, 0.3)
