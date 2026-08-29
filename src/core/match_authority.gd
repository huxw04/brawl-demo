class_name MatchAuthority
extends Node

signal authoritative_event_emitted(event: AuthoritativeEvent)
signal entity_registered(entity_id: int, entity_kind: StringName, entity: Node)
signal entity_unregistered(entity_id: int, entity_kind: StringName)

const MAX_EVENT_LOG_SIZE := 2048

var authority_tick := 0
var next_entity_id := 1
var next_event_id := 1
var entities: Dictionary = {}
var entity_descriptors: Dictionary = {}
var event_log: Array[AuthoritativeEvent] = []


func _ready() -> void:
	add_to_group("match_authority")
	# Advance the authority clock before ordinary combat nodes for this physics frame.
	process_physics_priority = -1000


func _physics_process(_delta: float) -> void:
	authority_tick += 1


func register_entity(
		entity: Node,
		entity_kind: StringName,
		requested_id: int = 0,
		initial_state: Dictionary = {}
) -> int:
	if entity == null or not is_instance_valid(entity):
		return 0
	var existing_id := int(entity.get_meta("authoritative_entity_id", 0))
	if existing_id > 0 and entities.get(existing_id) == entity:
		return existing_id
	var assigned_id := requested_id
	if assigned_id > 0 and entities.has(assigned_id):
		var occupied := entities.get(assigned_id) as Node
		if occupied != null and occupied.is_queued_for_deletion():
			unregister_entity(assigned_id, &"replaced")
		else:
			push_error("Authoritative entity id %d is already registered" % assigned_id)
			return 0
	if assigned_id <= 0:
		assigned_id = _allocate_entity_id()
	else:
		next_entity_id = maxi(next_entity_id, assigned_id + 1)
	entities[assigned_id] = entity
	var descriptor := {
		"entity_id": assigned_id,
		"entity_kind": str(entity_kind),
		"initial_state": initial_state.duplicate(true),
	}
	entity_descriptors[assigned_id] = descriptor
	entity.set_meta("authoritative_entity_id", assigned_id)
	_set_property_if_present(entity, &"entity_id", assigned_id)
	entity.tree_exiting.connect(_on_entity_tree_exiting.bind(assigned_id, entity.get_instance_id()), CONNECT_ONE_SHOT)
	entity_registered.emit(assigned_id, entity_kind, entity)
	emit_authoritative_event(AuthoritativeEvent.ENTITY_SPAWNED, assigned_id, descriptor)
	return assigned_id


func unregister_entity(entity_id: int, reason: StringName = &"removed") -> void:
	if not entities.has(entity_id):
		return
	var descriptor: Dictionary = entity_descriptors.get(entity_id, {})
	var entity_kind := StringName(str(descriptor.get("entity_kind", "unknown")))
	entities.erase(entity_id)
	entity_descriptors.erase(entity_id)
	entity_unregistered.emit(entity_id, entity_kind)
	emit_authoritative_event(AuthoritativeEvent.ENTITY_DESTROYED, entity_id, {
		"entity_kind": str(entity_kind),
		"vfx_id": str((descriptor.get("initial_state", {}) as Dictionary).get("vfx_id", "")),
		"reason": str(reason),
	})


func entity(entity_id: int) -> Node:
	var value := entities.get(entity_id) as Node
	return value if value != null and is_instance_valid(value) else null


func emit_authoritative_event(event_type: StringName, entity_id: int = 0, payload: Dictionary = {}) -> AuthoritativeEvent:
	var event := AuthoritativeEvent.create(next_event_id, authority_tick, event_type, entity_id, payload)
	next_event_id += 1
	event_log.append(event)
	if event_log.size() > MAX_EVENT_LOG_SIZE:
		event_log.pop_front()
	authoritative_event_emitted.emit(event)
	return event


func events_after(event_id: int) -> Array[AuthoritativeEvent]:
	var result: Array[AuthoritativeEvent] = []
	for event in event_log:
		if event.event_id > event_id:
			result.append(event)
	return result


func state_digest() -> Dictionary:
	var ids: Array[int] = []
	for value in entities.keys():
		ids.append(int(value))
	ids.sort()
	var snapshots: Array[Dictionary] = []
	for entity_id in ids:
		var registered := entity(entity_id)
		var snapshot: Dictionary
		if registered != null and registered.has_method("authoritative_snapshot"):
			snapshot = registered.call("authoritative_snapshot") as Dictionary
		else:
			snapshot = (entity_descriptors.get(entity_id, {}) as Dictionary).duplicate(true)
		snapshot["entity_id"] = entity_id
		if not snapshot.has("entity_kind"):
			var descriptor := entity_descriptors.get(entity_id, {}) as Dictionary
			snapshot["entity_kind"] = str(descriptor.get("entity_kind", "unknown"))
		snapshots.append(snapshot)
	return {
		"authority_tick": authority_tick,
		"next_entity_id": next_entity_id,
		"next_event_id": next_event_id,
		"entities": snapshots,
	}


func _allocate_entity_id() -> int:
	while entities.has(next_entity_id):
		next_entity_id += 1
	var result := next_entity_id
	next_entity_id += 1
	return result


func _on_entity_tree_exiting(entity_id: int, instance_id: int) -> void:
	var registered := entities.get(entity_id) as Node
	if registered == null or registered.get_instance_id() != instance_id:
		return
	unregister_entity(entity_id, &"tree_exiting")


func _set_property_if_present(object: Object, property_name: StringName, value: Variant) -> void:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			object.set(property_name, value)
			return
