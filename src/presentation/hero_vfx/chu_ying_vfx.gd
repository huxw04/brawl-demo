class_name ChuYingVfx
extends Node

## Pure presentation for Chu Ying. Stones, teleport resolution, damage and the
## barrier entity remain authoritative combat concerns.

var actor: CombatActor


func setup(p_actor: CombatActor) -> void:
	actor = p_actor


func spawn_board(position: Vector3) -> void:
	var board := Node3D.new()
	board.name = "ChuYingBoardRectangle"
	board.top_level = true
	board.add_to_group("transient_combat_vfx")
	board.add_to_group("chu_ying_board_rectangles")
	_world_parent().add_child(board)
	board.global_position = Vector3(position.x, 0.10, position.z)
	var pieces: Array[MeshInstance3D] = []
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(0.78, 0.018, 0.78)
	floor_mesh.material = _vfx_material(Color(0.46, 0.72, 1.0, 0.16))
	floor.mesh = floor_mesh
	board.add_child(floor)
	pieces.append(floor)
	for edge_index in range(4):
		var edge := MeshInstance3D.new()
		var horizontal := edge_index < 2
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.82, 0.028, 0.035) if horizontal else Vector3(0.035, 0.028, 0.82)
		edge_mesh.material = _vfx_material(Color(0.72, 0.88, 1.0, 0.76))
		edge.mesh = edge_mesh
		var side := -1.0 if edge_index % 2 == 0 else 1.0
		edge.position = Vector3(0.0, 0.024, side * 0.40) if horizontal else Vector3(side * 0.40, 0.024, 0.0)
		board.add_child(edge)
		pieces.append(edge)
	_add_light_walls(board, Vector2(0.41, 0.41), 0.65, pieces)
	board.scale = Vector3.ONE * 0.25
	var tween := board.create_tween()
	tween.tween_property(board, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.48)
	for piece in pieces:
		tween.parallel().tween_property(piece, "transparency", 1.0, 0.20)
	tween.tween_callback(board.queue_free)


func spawn_teleport_charge(duration: float) -> void:
	var circle := Node3D.new()
	circle.name = "ChuYingTeleportChargeCircle"
	circle.top_level = true
	circle.add_to_group("transient_combat_vfx")
	circle.add_to_group("chu_ying_teleport_charge")
	_world_parent().add_child(circle)
	circle.global_position = Vector3(actor.global_position.x, 0.052, actor.global_position.z)
	for ring_index in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.50 - ring_index * 0.15
		torus.outer_radius = 0.56 - ring_index * 0.15
		torus.rings = 40
		torus.ring_segments = 7
		torus.material = _vfx_material(Color(0.82, 0.92, 1.0, 0.42))
		ring.mesh = torus
		circle.add_child(ring)
	for spoke_index in range(8):
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(0.035, 0.018, 0.48)
		spoke_mesh.material = _vfx_material(Color(0.78, 0.90, 1.0, 0.26))
		spoke.mesh = spoke_mesh
		spoke.position = Vector3(sin(TAU * spoke_index / 8.0), 0.0, cos(TAU * spoke_index / 8.0)) * 0.25
		spoke.rotation.y = TAU * spoke_index / 8.0
		circle.add_child(spoke)
	var spin := circle.create_tween()
	spin.tween_property(circle, "rotation:y", TAU * 1.35, duration)
	spin.parallel().tween_property(circle, "scale", Vector3(0.82, 1.0, 0.82), duration)
	spin.tween_callback(circle.queue_free)


func spawn_teleport_ghost(position: Vector3) -> void:
	spawn_teleport_column(position)
	var ghost := Sprite3D.new()
	ghost.top_level = true
	ghost.add_to_group("transient_combat_vfx")
	_world_parent().add_child(ghost)
	ghost.texture = actor.base_sprite_texture
	ghost.pixel_size = actor.base_sprite_pixel_size
	ghost.global_position = position + Vector3.UP * actor.definition.sprite_y
	ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ghost.flip_h = actor.sprite.flip_h
	ghost.modulate = Color(0.72, 0.88, 1.0, 0.58)
	ghost.no_depth_test = false
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "scale", Vector3(1.18, 1.08, 1.0), 0.24)
	tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.24)
	tween.tween_callback(ghost.queue_free)


func spawn_teleport_column(position: Vector3) -> void:
	var column := MeshInstance3D.new()
	column.name = "ChuYingTeleportColumn"
	column.top_level = true
	column.add_to_group("transient_combat_vfx")
	column.add_to_group("chu_ying_teleport_columns")
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world_parent().add_child(column)
	column.global_position = Vector3(position.x, 1.25, position.z)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.23
	mesh.height = 2.5
	mesh.radial_segments = 24
	mesh.material = _vfx_material(Color(0.72, 0.88, 1.0, 0.34))
	column.mesh = mesh
	column.scale = Vector3(0.22, 0.65, 0.22)
	var tween := column.create_tween()
	tween.tween_property(column, "scale", Vector3.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(column, "scale", Vector3(0.12, 1.10, 0.12), 0.26)
	tween.parallel().tween_property(column, "transparency", 1.0, 0.26)
	tween.tween_callback(column.queue_free)


func _add_light_walls(anchor: Node3D, half_extents: Vector2, height: float, pieces: Array[MeshInstance3D]) -> void:
	for wall_index in range(4):
		var wall := MeshInstance3D.new()
		wall.name = "ChuYingLightWall"
		wall.add_to_group("chu_ying_light_walls")
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var along_x := wall_index < 2
		var quad := QuadMesh.new()
		quad.size = Vector2(half_extents.x * 2.0, height) if along_x else Vector2(half_extents.y * 2.0, height)
		quad.material = _light_wall_material()
		wall.mesh = quad
		var side := -1.0 if wall_index % 2 == 0 else 1.0
		wall.position = Vector3(0.0, height * 0.5, side * half_extents.y) if along_x else Vector3(side * half_extents.x, height * 0.5, 0.0)
		wall.rotation.y = 0.0 if along_x else PI * 0.5
		anchor.add_child(wall)
		pieces.append(wall)


func _light_wall_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
	float bottom_to_top = smoothstep(0.0, 0.92, UV.y);
	vec3 glow = vec3(0.56, 0.78, 1.0);
	ALBEDO = glow;
	EMISSION = glow * 1.8;
	ALPHA = bottom_to_top * 0.34;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _world_parent() -> Node:
	return actor.get_parent() if actor.get_parent() != null else actor


func _vfx_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
