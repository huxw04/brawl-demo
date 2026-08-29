class_name AuthoritativeEvent
extends RefCounted

const ENTITY_SPAWNED := &"entity_spawned"
const ENTITY_DESTROYED := &"entity_destroyed"
const WORLD_EFFECT := &"world_effect"
const HERO_EFFECT := &"hero_effect"
const MATCH_RULE := &"match_rule"

var event_id := 0
var authority_tick := 0
var event_type := StringName()
var entity_id := 0
var payload: Dictionary = {}


static func create(
		p_event_id: int,
		p_authority_tick: int,
		p_event_type: StringName,
		p_entity_id: int = 0,
		p_payload: Dictionary = {}
) -> AuthoritativeEvent:
	var event := AuthoritativeEvent.new()
	event.event_id = p_event_id
	event.authority_tick = p_authority_tick
	event.event_type = p_event_type
	event.entity_id = p_entity_id
	event.payload = p_payload.duplicate(true)
	return event


func to_packet() -> Dictionary:
	return {
		"event_id": event_id,
		"authority_tick": authority_tick,
		"event_type": str(event_type),
		"entity_id": entity_id,
		"payload": payload.duplicate(true),
	}


static func from_packet(packet: Dictionary) -> AuthoritativeEvent:
	return create(
		maxi(0, int(packet.get("event_id", 0))),
		maxi(0, int(packet.get("authority_tick", 0))),
		StringName(str(packet.get("event_type", ""))),
		maxi(0, int(packet.get("entity_id", 0))),
		packet.get("payload", {}) as Dictionary
	)
