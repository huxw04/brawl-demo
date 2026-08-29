class_name MatchReplica
extends Node

signal actor_snapshot_applied(actor_id: int, server_tick: int)
signal authoritative_event_emitted(event: AuthoritativeEvent)
signal entity_replica_created(entity_id: int, entity_kind: String, initial_state: Dictionary)
signal entity_replica_removed(entity_id: int)

const ReplicaCombatEntityScript = preload("res://src/network/replica_combat_entity.gd")

var expected_match_id := 0
var actors_by_id: Dictionary = {}
var last_applied_ticks: Dictionary = {}
var entities_by_id: Dictionary = {}
var last_authoritative_event_id := 0
var last_entity_snapshot_tick := -1
var latest_snapshot_entity_ids: Dictionary = {}
var entity_spawn_count := 0
var entity_remove_count := 0
var entity_snapshot_apply_count := 0
var entity_motion_observed_count := 0
var entity_spawn_counts_by_vfx: Dictionary = {}
var entity_spawn_counts_by_kind: Dictionary = {}
var stale_actor_snapshot_count := 0
var stale_entity_snapshot_count := 0
var stale_authoritative_event_count := 0
var recovered_entity_spawn_count := 0
var recovered_entity_remove_count := 0


func setup(p_match_id: int) -> void:
	expected_match_id = p_match_id
	last_applied_ticks.clear()
	last_authoritative_event_id = 0
	last_entity_snapshot_tick = -1
	latest_snapshot_entity_ids.clear()
	entity_spawn_count = 0
	entity_remove_count = 0
	entity_snapshot_apply_count = 0
	entity_motion_observed_count = 0
	entity_spawn_counts_by_vfx.clear()
	entity_spawn_counts_by_kind.clear()
	stale_actor_snapshot_count = 0
	stale_entity_snapshot_count = 0
	stale_authoritative_event_count = 0
	recovered_entity_spawn_count = 0
	recovered_entity_remove_count = 0
	_clear_entities()


func register_actor(actor: CombatActor) -> void:
	if actor == null:
		return
	actors_by_id[actor.battle_id] = actor
	actor.set_authority_replica_mode(true)


func unregister_actor(actor_id: int) -> void:
	actors_by_id.erase(actor_id)
	last_applied_ticks.erase(actor_id)


func apply_actor_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("match_id", -1)) != expected_match_id:
		return false
	var actor_value = snapshot.get("actor", {})
	if not actor_value is Dictionary:
		return false
	var actor_packet := actor_value as Dictionary
	var actor_id := int(actor_packet.get("actor_id", 0))
	var server_tick := int(snapshot.get("server_tick", -1))
	if not actors_by_id.has(actor_id):
		return false
	if server_tick <= int(last_applied_ticks.get(actor_id, -1)):
		stale_actor_snapshot_count += 1
		return false
	var actor := actors_by_id.get(actor_id) as CombatActor
	if actor == null or not is_instance_valid(actor):
		return false
	last_applied_ticks[actor_id] = server_tick
	actor.apply_authoritative_network_state(actor_packet)
	actor_snapshot_applied.emit(actor_id, server_tick)
	return true


func entity(entity_id: int) -> Node:
	var value := entities_by_id.get(entity_id) as Node
	if value != null and is_instance_valid(value):
		return value
	var actor_value := actors_by_id.get(entity_id) as Node
	return actor_value if actor_value != null and is_instance_valid(actor_value) else null


func apply_authoritative_event(envelope: Dictionary) -> bool:
	if int(envelope.get("match_id", -1)) != expected_match_id:
		return false
	var packet_value = envelope.get("event", {})
	if not packet_value is Dictionary:
		return false
	var event := AuthoritativeEvent.from_packet(packet_value as Dictionary)
	if event.event_id <= last_authoritative_event_id:
		stale_authoritative_event_count += 1
		return false
	last_authoritative_event_id = event.event_id
	if event.event_type == AuthoritativeEvent.ENTITY_SPAWNED:
		var descriptor := event.payload
		if not _is_supported_entity(str(descriptor.get("entity_kind", "")), descriptor.get("initial_state", {}) as Dictionary):
			return false
		var replica := _ensure_entity(event.entity_id, str(descriptor.get("entity_kind", "")), descriptor.get("initial_state", {}) as Dictionary)
		if replica == null:
			return false
	elif event.event_type == AuthoritativeEvent.ENTITY_DESTROYED:
		_remove_entity(event.entity_id, false)
	authoritative_event_emitted.emit(event)
	return true


func apply_entity_snapshot(envelope: Dictionary) -> bool:
	if int(envelope.get("match_id", -1)) != expected_match_id:
		return false
	var server_tick := int(envelope.get("server_tick", -1))
	if server_tick <= last_entity_snapshot_tick:
		stale_entity_snapshot_count += 1
		return false
	var values = envelope.get("entities", [])
	if not values is Array:
		return false
	last_entity_snapshot_tick = server_tick
	var present_ids: Dictionary = {}
	for value in values as Array:
		if not value is Dictionary:
			continue
		var snapshot := value as Dictionary
		var entity_id := int(snapshot.get("entity_id", 0))
		var entity_kind := str(snapshot.get("entity_kind", ""))
		if entity_id <= 0 or not _is_supported_entity(entity_kind, snapshot):
			continue
		present_ids[entity_id] = true
		var replica := entity(entity_id) as ReplicaCombatEntity
		if replica == null:
			recovered_entity_spawn_count += 1
			replica = _ensure_entity(entity_id, entity_kind, _presentation_state_from_snapshot(snapshot))
		if replica != null:
			var previous_position := replica.position_target
			if replica.apply_authoritative_snapshot(snapshot, server_tick):
				entity_snapshot_apply_count += 1
				if replica.position_target.distance_to(previous_position) > 0.001:
					entity_motion_observed_count += 1
	latest_snapshot_entity_ids = present_ids
	for entity_id_value in entities_by_id.keys():
		var entity_id := int(entity_id_value)
		if not present_ids.has(entity_id):
			recovered_entity_remove_count += 1
			_remove_entity(entity_id)
	return true


func _ensure_entity(entity_id: int, entity_kind: String, initial_state: Dictionary) -> ReplicaCombatEntity:
	var existing := entity(entity_id) as ReplicaCombatEntity
	if existing != null:
		return existing
	var replica := ReplicaCombatEntityScript.new() as ReplicaCombatEntity
	add_child(replica)
	replica.configure_from_spawn(entity_id, entity_kind, initial_state)
	entities_by_id[entity_id] = replica
	entity_spawn_count += 1
	entity_spawn_counts_by_kind[entity_kind] = int(entity_spawn_counts_by_kind.get(entity_kind, 0)) + 1
	var vfx_id := str(initial_state.get("vfx_id", ""))
	entity_spawn_counts_by_vfx[vfx_id] = int(entity_spawn_counts_by_vfx.get(vfx_id, 0)) + 1
	entity_replica_created.emit(entity_id, entity_kind, replica.presentation_state())
	return replica


func _remove_entity(entity_id: int, notify_presentation := true) -> void:
	var replica := entity(entity_id)
	if replica == null:
		entities_by_id.erase(entity_id)
		return
	entities_by_id.erase(entity_id)
	entity_remove_count += 1
	if notify_presentation:
		entity_replica_removed.emit(entity_id)
	replica.queue_free()


func _clear_entities() -> void:
	for entity_id_value in entities_by_id.keys():
		_remove_entity(int(entity_id_value))
	entities_by_id.clear()


func _is_supported_entity(entity_kind: String, state: Dictionary) -> bool:
	return entity_kind in ["projectile", "delayed_attack", "chu_ying_stone", "chu_ying_barrier"]


func _presentation_state_from_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"vfx_id": str(snapshot.get("vfx_id", "")),
		"position": _dequantize_vector(snapshot.get("position", [])),
		"direction": _dequantize_vector(snapshot.get("direction", [])),
		"source_id": int(snapshot.get("source_id", 0)),
		"ability_id": str(snapshot.get("ability_id", "")),
		"attack_id": int(snapshot.get("attack_id", 0)),
		"radius": float(snapshot.get("radius", 0)) / 10000.0,
		"color": _dequantize_color(snapshot.get("color", [])),
		"remaining": float(snapshot.get("remaining", 0)) / 10000.0,
		"fall": float(snapshot.get("fall", 0)) / 10000.0,
		"flying": bool(snapshot.get("flying", false)),
		"half_extents": _dequantize_vector2(snapshot.get("half_extents", [])),
	}


func _dequantize_vector(value: Variant) -> Array[float]:
	if value is Array and (value as Array).size() >= 3:
		return [float(value[0]) / 10000.0, float(value[1]) / 10000.0, float(value[2]) / 10000.0]
	return [0.0, 0.0, 0.0]


func _dequantize_color(value: Variant) -> Array[float]:
	if value is Array and (value as Array).size() >= 4:
		return [float(value[0]) / 10000.0, float(value[1]) / 10000.0, float(value[2]) / 10000.0, float(value[3]) / 10000.0]
	return [1.0, 1.0, 1.0, 1.0]


func _dequantize_vector2(value: Variant) -> Array[float]:
	if value is Array and (value as Array).size() >= 2:
		return [float(value[0]) / 10000.0, float(value[1]) / 10000.0]
	return [0.0, 0.0]
