class_name ReplicaCombatEntity
extends Node3D

var entity_id := 0
var entity_kind := ""
var vfx_id := ""
var direction := Vector3.RIGHT
var last_server_tick := -1
var presentation_data: Dictionary = {}
var remaining := 0.0
var radius := 0.0
var fall_remaining := 0.0
var flying := false
var half_extents := Vector2.ZERO
var position_target := Vector3.ZERO
var estimated_velocity := Vector3.ZERO
var snapshot_age := 0.0


func configure_from_spawn(p_entity_id: int, p_entity_kind: String, initial_state: Dictionary) -> void:
	entity_id = p_entity_id
	entity_kind = p_entity_kind
	vfx_id = str(initial_state.get("vfx_id", ""))
	presentation_data = initial_state.duplicate(true)
	name = "ReplicaEntity_%d" % entity_id
	global_position = _vector_from_float_packet(initial_state.get("position", []), global_position)
	position_target = global_position
	direction = _vector_from_float_packet(initial_state.get("direction", []), direction).normalized()
	remaining = float(initial_state.get("remaining", 0.0))
	radius = float(initial_state.get("radius", 0.0))
	fall_remaining = float(initial_state.get("fall", 0.0))
	flying = bool(initial_state.get("flying", false))
	half_extents = _vector2_from_float_packet(initial_state.get("half_extents", []), Vector2.ZERO)
	set_process(true)
	set_physics_process(false)


func _process(delta: float) -> void:
	snapshot_age += delta
	var destination := position_target + estimated_velocity * minf(snapshot_age, 0.12)
	if global_position.distance_to(destination) > 2.0:
		global_position = destination
		return
	var smoothing := 1.0 - exp(-24.0 * delta)
	global_position = global_position.lerp(destination, smoothing)


func apply_authoritative_snapshot(snapshot: Dictionary, server_tick: int) -> bool:
	if server_tick <= last_server_tick:
		return false
	var previous_server_tick := last_server_tick
	last_server_tick = server_tick
	entity_kind = str(snapshot.get("entity_kind", entity_kind))
	vfx_id = str(snapshot.get("vfx_id", vfx_id))
	for key in ["source_id", "ability_id", "vfx_id", "attack_id", "radius", "color"]:
		if snapshot.has(key):
			presentation_data[key] = snapshot[key]
	var next_position := _vector_from_quantized_packet(snapshot.get("position", []), position_target)
	if previous_server_tick >= 0:
		var tick_delta := float(server_tick - previous_server_tick) / 60.0
		estimated_velocity = (next_position - position_target) / maxf(tick_delta, 0.001)
		if estimated_velocity.length() > 24.0:
			estimated_velocity = estimated_velocity.normalized() * 24.0
	position_target = next_position
	snapshot_age = 0.0
	if global_position.distance_to(position_target) > 2.0:
		global_position = position_target
	var next_direction := _vector_from_quantized_packet(snapshot.get("direction", []), direction)
	if next_direction.length_squared() > 0.0001:
		direction = next_direction.normalized()
	remaining = _dequantize(snapshot.get("remaining", roundi(remaining * 10000.0)))
	radius = _dequantize(snapshot.get("radius", roundi(radius * 10000.0)))
	fall_remaining = _dequantize(snapshot.get("fall", roundi(fall_remaining * 10000.0)))
	flying = bool(snapshot.get("flying", flying))
	half_extents = _vector2_from_quantized_packet(snapshot.get("half_extents", []), half_extents)
	return true


func presentation_state() -> Dictionary:
	var result := presentation_data.duplicate(true)
	result.merge({
		"vfx_id": vfx_id,
		"position": [global_position.x, global_position.y, global_position.z],
		"direction": [direction.x, direction.y, direction.z],
	}, true)
	return result


func _vector_from_float_packet(packet: Variant, fallback: Vector3) -> Vector3:
	if packet is Array and (packet as Array).size() >= 3:
		return Vector3(float(packet[0]), float(packet[1]), float(packet[2]))
	return fallback


func _vector_from_quantized_packet(packet: Variant, fallback: Vector3) -> Vector3:
	if packet is Array and (packet as Array).size() >= 3:
		return Vector3(float(packet[0]), float(packet[1]), float(packet[2])) / 10000.0
	return fallback


func _vector2_from_float_packet(packet: Variant, fallback: Vector2) -> Vector2:
	if packet is Array and (packet as Array).size() >= 2:
		return Vector2(float(packet[0]), float(packet[1]))
	return fallback


func _vector2_from_quantized_packet(packet: Variant, fallback: Vector2) -> Vector2:
	if packet is Array and (packet as Array).size() >= 2:
		return Vector2(float(packet[0]), float(packet[1])) / 10000.0
	return fallback


func _dequantize(value: Variant) -> float:
	return float(value) / 10000.0
