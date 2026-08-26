class_name AbilityTargetingPreview
extends Node3D

const HEIGHT := 0.058
const VALID_RGB := Color("9addec")
const INVALID_RGB := Color("f09a72")

var actor: CombatActor
var controller: MobaPlayerController
var preview_mesh := ImmediateMesh.new()
var preview_instance := MeshInstance3D.new()
var fill_material: StandardMaterial3D
var edge_material: StandardMaterial3D
var faint_material: StandardMaterial3D
var interior_material: StandardMaterial3D
var hold_fill_material: StandardMaterial3D
var invalid_fill_material: StandardMaterial3D
var invalid_edge_material: StandardMaterial3D
var shown_ability_id := ""
var last_target: CombatActor


func _ready() -> void:
	preview_instance.name = "TargetingGeometry"
	preview_instance.mesh = preview_mesh
	preview_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(preview_instance)
	fill_material = _material(Color(VALID_RGB, 0.040))
	edge_material = _material(Color(VALID_RGB, 0.22))
	faint_material = _material(Color(VALID_RGB, 0.09))
	interior_material = _material(Color(VALID_RGB, 0.13))
	hold_fill_material = _material(Color(VALID_RGB, 0.035))
	invalid_fill_material = _material(Color(INVALID_RGB, 0.055))
	invalid_edge_material = _material(Color(INVALID_RGB, 0.34))
	preview_instance.visible = false


func setup(p_actor: CombatActor, p_controller: MobaPlayerController) -> void:
	actor = p_actor
	controller = p_controller
	clear()


func clear() -> void:
	shown_ability_id = ""
	last_target = null
	preview_mesh.clear_surfaces()
	preview_instance.visible = false


func _process(_delta: float) -> void:
	if actor == null or controller == null or actor.is_defeated:
		clear()
		return
	var ability_id := controller.pending_ability
	if ability_id.is_empty():
		_draw_active_hold_preview()
		return
	var ability := actor.ability_by_id(ability_id)
	if ability == null or ability.disabled or ability.targeting_preview == "none":
		clear()
		return
	shown_ability_id = ability_id
	preview_mesh.clear_surfaces()
	last_target = null
	_draw_ability(ability, controller.mouse_ground)
	preview_instance.visible = preview_mesh.get_surface_count() > 0


func _draw_ability(ability: AbilityDefinition, mouse: Vector3) -> void:
	var origin := _flat(actor.global_position)
	var offset := _flat(mouse) - origin
	var direction := actor.facing
	if offset.length_squared() > 0.001:
		direction = offset.normalized()
	var range := _preview_range(ability)
	var outside_range := range > 0.0 and offset.length() > range + 0.001
	var endpoint := origin + direction * minf(offset.length(), range) if range > 0.0 else _flat(mouse)
	var fill := invalid_fill_material if outside_range else fill_material
	var edge := invalid_edge_material if outside_range else edge_material
	match ability.targeting_preview:
		"line":
			endpoint = origin + direction * range
			endpoint = _line_collision_endpoint(origin, endpoint, ability)
			_draw_corridor(origin, endpoint, maxf(0.08, ability.targeting_preview_width), fill, edge)
			_draw_circle(endpoint, maxf(0.055, ability.targeting_preview_width * 0.34), edge, false)
		"box":
			_draw_oriented_box(origin + direction * ability.hitbox_distance, direction, ability.hitbox_size.x, ability.hitbox_size.z, fill, edge)
			_draw_direction_marks(origin, origin + direction * (ability.hitbox_distance + ability.hitbox_size.z * 0.5), minf(ability.hitbox_size.x, 0.70), interior_material)
			if ability.targeting_preview_secondary_radius > 0.0:
				_draw_circle(origin + direction * ability.delayed_center_distance, ability.targeting_preview_secondary_radius, faint_material, false)
		"dash":
			endpoint = origin + direction * range
			_draw_corridor(origin, endpoint, maxf(0.10, ability.targeting_preview_width), fill, edge)
			_draw_circle(endpoint, actor.definition.body_radius, edge, false)
		"point":
			_draw_circle(origin, range, faint_material, false)
			if ability.vfx_id == "chu_ying_teleport":
				endpoint = _safe_endpoint(endpoint, actor.definition.body_radius * 0.88, 20)
			_draw_circle(endpoint, maxf(0.08, ability.targeting_preview_radius), fill, true, edge)
			_draw_target_reticle(endpoint, maxf(0.08, ability.targeting_preview_radius))
			if ability.targeting_preview_secondary_radius > 0.0:
				_draw_circle(endpoint, ability.targeting_preview_secondary_radius, faint_material, false)
		"leap":
			endpoint = _safe_endpoint(endpoint, actor.definition.body_radius * 0.88, 12)
			_draw_corridor(origin, endpoint, 0.055, faint_material, edge)
			_draw_circle(endpoint, maxf(0.08, ability.targeting_preview_radius), fill, true, edge)
			_draw_target_reticle(endpoint, maxf(0.08, ability.targeting_preview_radius))
		"unit":
			_draw_circle(origin, range, faint_material, false)
			last_target = _find_unit_target(mouse, range)
			if last_target != null:
				var target_position := _flat(last_target.global_position)
				_draw_corridor(origin, target_position, 0.035, faint_material, faint_material)
				_draw_circle(target_position, last_target.definition.body_radius + 0.16, fill_material, true, edge_material)
				var target_facing := _flat(last_target.facing).normalized()
				if target_facing.length_squared() <= 0.001:
					target_facing = -_flat(actor.facing).normalized()
				var landing := target_position - target_facing * (last_target.definition.body_radius + actor.definition.body_radius + 0.16)
				_draw_circle(landing, actor.definition.body_radius, faint_material, false)
			else:
				_draw_circle(endpoint, 0.16, invalid_fill_material, true, invalid_edge_material)
		"barrier":
			_draw_circle(origin, range, faint_material, false)
			var center := (origin + endpoint) * 0.5
			var half_extents := Vector2(maxf(absf(endpoint.x - origin.x) * 0.5, 0.5), maxf(absf(endpoint.z - origin.z) * 0.5, 0.5))
			_draw_axis_aligned_box(center, half_extents, fill, edge)
			_draw_segment_strip(center + Vector3(-half_extents.x, 0.0, 0.0), center + Vector3(half_extents.x, 0.0, 0.0), 0.018, faint_material)
			_draw_segment_strip(center + Vector3(0.0, 0.0, -half_extents.y), center + Vector3(0.0, 0.0, half_extents.y), 0.018, faint_material)
			_draw_direction_marks(origin, endpoint, minf(maxf(half_extents.x, half_extents.y) * 2.0, 0.70), interior_material)


func _draw_active_hold_preview() -> void:
	if actor.current_ability == null or not actor.current_ability.hold_to_channel:
		clear()
		return
	preview_mesh.clear_surfaces()
	shown_ability_id = actor.current_ability.ability_id
	var origin := _flat(actor.global_position)
	if actor.current_ability.vfx_id == "shield_guard":
		_draw_sector(origin, _flat(actor.facing), 1.35, actor.current_ability.front_block_degrees, hold_fill_material, faint_material)
	elif actor.current_ability.vfx_id == "nailoong_fire_breath":
		_draw_sector(origin, _flat(actor.facing), 3.0, 48.0, hold_fill_material, faint_material)
	preview_instance.visible = preview_mesh.get_surface_count() > 0


func _preview_range(ability: AbilityDefinition) -> float:
	if ability.targeting_preview_range > 0.0:
		return ability.targeting_preview_range
	if ability.target_required_range > 0.0:
		return ability.target_required_range
	if ability.dash_distance > 0.0:
		return ability.dash_distance
	if ability.is_projectile():
		return ability.projectile_speed * ability.projectile_lifetime
	return ability.hitbox_distance + ability.hitbox_size.z * 0.5


func _line_collision_endpoint(origin: Vector3, endpoint: Vector3, ability: AbilityDefinition) -> Vector3:
	var height := ability.projectile_height
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * height, endpoint + Vector3.UP * height, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	var resolved := _flat(Vector3(hit["position"])) if not hit.is_empty() else endpoint
	if ability.vfx_id != "bear_grapple":
		return resolved
	var direction := (endpoint - origin).normalized()
	var max_distance := origin.distance_to(resolved)
	for value in actor.get_tree().get_nodes_in_group("combat_actors"):
		if not value is CombatActor:
			continue
		var candidate := value as CombatActor
		if candidate == actor or candidate.team == actor.team or candidate.is_defeated or not candidate.is_targetable():
			continue
		var relative := _flat(candidate.global_position) - origin
		var forward := relative.dot(direction)
		if forward <= 0.0 or forward >= max_distance:
			continue
		var perpendicular := (relative - direction * forward).length()
		if perpendicular <= candidate.definition.body_radius + ability.projectile_radius:
			max_distance = forward
			resolved = origin + direction * forward
	return resolved


func _find_unit_target(mouse: Vector3, max_range: float) -> CombatActor:
	var pointed: CombatActor
	var pointed_distance := 1.10 * 1.10
	var nearest: CombatActor
	var nearest_distance := max_range * max_range
	for value in actor.get_tree().get_nodes_in_group("combat_actors"):
		if not value is CombatActor:
			continue
		var candidate := value as CombatActor
		if candidate == actor or candidate.team == actor.team or candidate.is_defeated or not candidate.is_targetable() or not candidate.is_visible_to(actor.team):
			continue
		var source_distance := _flat(candidate.global_position).distance_squared_to(_flat(actor.global_position))
		if source_distance > max_range * max_range:
			continue
		var point_distance := _flat(mouse).distance_squared_to(_flat(candidate.global_position))
		if point_distance <= pointed_distance:
			pointed = candidate
			pointed_distance = point_distance
		if source_distance <= nearest_distance:
			nearest = candidate
			nearest_distance = source_distance
	return pointed if pointed != null else nearest


func _safe_endpoint(preferred: Vector3, radius: float, steps: int) -> Vector3:
	var origin := _flat(actor.global_position)
	var offset := preferred - origin
	var shape := SphereShape3D.new()
	shape.radius = radius
	for step in range(steps + 1):
		var ratio := 1.0 - float(step) / float(steps)
		var candidate := origin + offset * ratio
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * actor.definition.body_radius)
		query.collision_mask = 1
		if actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return origin


func _draw_corridor(from: Vector3, to: Vector3, width: float, fill: Material, edge: Material) -> void:
	var direction := to - from
	if direction.length_squared() <= 0.0001:
		return
	var length := direction.length()
	direction = direction.normalized()
	var right := Vector3(-direction.z, 0.0, direction.x) * width * 0.5
	var shoulder := to - direction * minf(maxf(0.16, width * 0.55), length * 0.24)
	_draw_polygon([from - right, from + right, shoulder + right, to, shoulder - right], fill, edge)
	_draw_direction_marks(from, to, minf(width, 0.70), interior_material)


func _draw_oriented_box(center: Vector3, forward: Vector3, width: float, length: float, fill: Material, edge: Material) -> void:
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var half_forward := forward * length * 0.5
	var half_right := right * width * 0.5
	_draw_quad([center - half_forward - half_right, center - half_forward + half_right, center + half_forward + half_right, center + half_forward - half_right], fill, edge)


func _draw_axis_aligned_box(center: Vector3, half_extents: Vector2, fill: Material, edge: Material) -> void:
	_draw_quad([
		center + Vector3(-half_extents.x, 0.0, -half_extents.y),
		center + Vector3(half_extents.x, 0.0, -half_extents.y),
		center + Vector3(half_extents.x, 0.0, half_extents.y),
		center + Vector3(-half_extents.x, 0.0, half_extents.y),
	], fill, edge)


func _draw_quad(points: Array[Vector3], fill: Material, edge: Material) -> void:
	_draw_polygon(points, fill, edge)


func _draw_polygon(points: Array[Vector3], fill: Material, edge: Material) -> void:
	if points.size() < 3:
		return
	preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill)
	for index in range(1, points.size() - 1):
		preview_mesh.surface_add_vertex(_raised(points[0]))
		preview_mesh.surface_add_vertex(_raised(points[index]))
		preview_mesh.surface_add_vertex(_raised(points[index + 1]))
	preview_mesh.surface_end()
	for index in range(points.size()):
		_draw_segment_strip(points[index], points[(index + 1) % points.size()], 0.026, edge)


func _draw_circle(center: Vector3, radius: float, material: Material, filled: bool, outline: Material = null) -> void:
	const SEGMENTS := 48
	if filled:
		preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
		for index in range(SEGMENTS):
			preview_mesh.surface_add_vertex(_raised(center))
			preview_mesh.surface_add_vertex(_raised(center + Vector3(cos(TAU * index / SEGMENTS), 0.0, sin(TAU * index / SEGMENTS)) * radius))
			preview_mesh.surface_add_vertex(_raised(center + Vector3(cos(TAU * (index + 1) / SEGMENTS), 0.0, sin(TAU * (index + 1) / SEGMENTS)) * radius))
		preview_mesh.surface_end()
	_draw_ring_band(center, radius, minf(0.030, maxf(0.016, radius * 0.16)), outline if outline != null else material, SEGMENTS)


func _draw_sector(center: Vector3, forward: Vector3, radius: float, degrees: float, fill: Material, edge: Material) -> void:
	const SEGMENTS := 24
	var base_angle := atan2(forward.z, forward.x)
	var half_angle := deg_to_rad(degrees) * 0.5
	preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill)
	for index in range(SEGMENTS):
		var a0 := base_angle - half_angle + half_angle * 2.0 * index / SEGMENTS
		var a1 := base_angle - half_angle + half_angle * 2.0 * (index + 1) / SEGMENTS
		preview_mesh.surface_add_vertex(_raised(center))
		preview_mesh.surface_add_vertex(_raised(center + Vector3(cos(a0), 0.0, sin(a0)) * radius))
		preview_mesh.surface_add_vertex(_raised(center + Vector3(cos(a1), 0.0, sin(a1)) * radius))
	preview_mesh.surface_end()
	var first := center + Vector3(cos(base_angle - half_angle), 0.0, sin(base_angle - half_angle)) * radius
	var last := center + Vector3(cos(base_angle + half_angle), 0.0, sin(base_angle + half_angle)) * radius
	_draw_segment_strip(center, first, 0.022, edge)
	var arc_points: Array[Vector3] = []
	for index in range(SEGMENTS):
		var a0 := base_angle - half_angle + half_angle * 2.0 * index / SEGMENTS
		arc_points.append(center + Vector3(cos(a0), 0.0, sin(a0)) * radius)
	arc_points.append(last)
	for index in range(arc_points.size() - 1):
		_draw_segment_strip(arc_points[index], arc_points[index + 1], 0.022, edge)
	_draw_segment_strip(last, center, 0.022, edge)
	_draw_direction_marks(center, center + forward.normalized() * radius, minf(radius * 0.42, 0.58), interior_material)


func _draw_direction_marks(from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var direction := to - from
	if direction.length_squared() <= 0.01:
		return
	var length := direction.length()
	direction = direction.normalized()
	var right := Vector3(-direction.z, 0.0, direction.x)
	var arm := clampf(width * 0.28, 0.07, 0.18)
	var stroke := clampf(width * 0.055, 0.016, 0.030)
	var mark_count := clampi(floori(length / 0.82), 1, 4)
	for index in range(mark_count):
		var ratio := float(index + 1) / float(mark_count + 1)
		var center := from.lerp(to, ratio)
		var tip := center + direction * minf(0.11, length * 0.08)
		var back := center - direction * minf(0.08, length * 0.06)
		_draw_segment_strip(back - right * arm, tip, stroke, material)
		_draw_segment_strip(back + right * arm, tip, stroke, material)


func _draw_target_reticle(center: Vector3, radius: float) -> void:
	var inner_radius := clampf(radius * 0.24, 0.055, 0.16)
	_draw_ring_band(center, inner_radius, 0.018, interior_material, 28)
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		_draw_segment_strip(center + direction * radius * 0.48, center + direction * radius * 0.72, 0.020, interior_material)


func _draw_ring_band(center: Vector3, radius: float, thickness: float, material: Material, segments: int) -> void:
	var inner_radius := maxf(0.001, radius - thickness * 0.5)
	var outer_radius := radius + thickness * 0.5
	preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for index in range(segments):
		var a0 := TAU * index / segments
		var a1 := TAU * (index + 1) / segments
		var inner0 := center + Vector3(cos(a0), 0.0, sin(a0)) * inner_radius
		var outer0 := center + Vector3(cos(a0), 0.0, sin(a0)) * outer_radius
		var inner1 := center + Vector3(cos(a1), 0.0, sin(a1)) * inner_radius
		var outer1 := center + Vector3(cos(a1), 0.0, sin(a1)) * outer_radius
		for point in [inner0, outer0, outer1, inner0, outer1, inner1]:
			preview_mesh.surface_add_vertex(_raised(point))
	preview_mesh.surface_end()


func _draw_segment_strip(from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var direction := to - from
	if direction.length_squared() <= 0.000001:
		return
	direction = direction.normalized()
	var right := Vector3(-direction.z, 0.0, direction.x) * width * 0.5
	preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for point in [from - right, from + right, to + right, from - right, to + right, to - right]:
		preview_mesh.surface_add_vertex(_raised(point))
	preview_mesh.surface_end()


func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


func _raised(value: Vector3) -> Vector3:
	return Vector3(value.x, HEIGHT, value.z)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The preview is assembled from many camera-facing ground strips. Their
	# winding changes with aim direction, so back-face culling can make every
	# thick band disappear even though one-pixel line primitives were visible.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.no_depth_test = false
	material.render_priority = 2
	return material
