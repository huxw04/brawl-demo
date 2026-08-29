extends SceneTree

var failures: Array[String] = []
var accepted_by_channel: Dictionary = {}
var rejected_by_channel: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var replica := MatchReplica.new()
	root.add_child(replica)
	replica.setup(404)
	var presentation := AuthorityEventPresentation.new()
	root.add_child(presentation)
	presentation.setup_source(replica)
	var actor := CombatActor.new()
	root.add_child(actor)
	actor.setup(SwordShieldDog.create(), 1, "fault replica")
	actor.battle_id = 1
	replica.register_actor(actor)

	# Channel 2 is deliberately delayed, duplicated and reordered. Ticks 1..9
	# are omitted entirely to model a snapshot blackout.
	_deliver_schedule(replica, [
		{"at": 5, "channel": "actor", "packet": _actor_snapshot(404, 10, Vector3(10.0, 0.05, 0.0), 80.0)},
		{"at": 10, "channel": "actor", "packet": _actor_snapshot(404, 12, Vector3(12.0, 0.05, 0.0), 60.0)},
		{"at": 20, "channel": "actor", "packet": _actor_snapshot(404, 11, Vector3(11.0, 0.05, 0.0), 70.0)},
		{"at": 25, "channel": "actor", "packet": _actor_snapshot(404, 12, Vector3(99.0, 0.05, 0.0), 1.0)},
	])
	_check(replica.last_applied_ticks.get(1) == 12, "actor replica should keep the newest tick across delay, reordering and duplication")
	_check(actor.replica_position_target.distance_to(Vector3(12.0, 0.05, 0.0)) < 0.001 and is_equal_approx(actor.hp, 60.0), "late and duplicate actor snapshots must not roll state backward")
	_check(int(accepted_by_channel.get("actor", 0)) == 2 and int(rejected_by_channel.get("actor", 0)) == 2, "fault harness should observe two accepted and two rejected actor snapshots")
	_check(replica.stale_actor_snapshot_count == 2, "replica diagnostics should count stale actor packets")

	# A complete entity snapshot repairs a dropped reliable spawn. A newer
	# complete empty set repairs a dropped reliable destroy.
	_deliver_schedule(replica, [
		{"at": 5, "channel": "entity", "packet": _entity_snapshot(404, 100, [_projectile(31, 10000)])},
		{"at": 10, "channel": "entity", "packet": _entity_snapshot(404, 102, [_projectile(31, 30000)])},
		{"at": 20, "channel": "entity", "packet": _entity_snapshot(404, 101, [_projectile(31, 20000)])},
		{"at": 25, "channel": "entity", "packet": _entity_snapshot(404, 102, [_projectile(31, 990000)])},
	])
	var recovered := replica.entity(31) as ReplicaCombatEntity
	_check(recovered != null and recovered.position_target.distance_to(Vector3(3.0, 0.05, 0.0)) < 0.001, "full entity snapshots should recover a missed spawn and ignore stale motion")
	_check(presentation.entity_visuals.has(31), "snapshot recovery should also rebuild presentation")
	_check(replica.stale_entity_snapshot_count == 2 and replica.recovered_entity_spawn_count == 1, "replica diagnostics should record entity reordering and missed-spawn recovery")
	_deliver(replica, "entity", _entity_snapshot(404, 103, []))
	_check(replica.entity(31) == null and not presentation.entity_visuals.has(31), "next complete entity set should recover a missed destroy")
	_check(replica.recovered_entity_remove_count == 1, "replica diagnostics should record complete-set destroy recovery")

	# Reliable channel duplicates are idempotent. Artificial same-channel
	# reordering is outside ENet's contract, but old event ids must still fail
	# closed instead of replaying an obsolete effect.
	var spawn := _entity_event(404, 1, AuthoritativeEvent.ENTITY_SPAWNED, 60)
	_check(_deliver(replica, "event", spawn), "first reliable spawn should apply")
	_check(not _deliver(replica, "event", spawn), "duplicate reliable spawn should be ignored")
	var destroy := _entity_event(404, 2, AuthoritativeEvent.ENTITY_DESTROYED, 60)
	_check(_deliver(replica, "event", destroy), "first reliable destroy should apply")
	_check(not _deliver(replica, "event", destroy), "duplicate reliable destroy should be ignored")
	_check(replica.entity(60) == null and replica.entity_spawn_count >= 2, "duplicate lifecycle events must not duplicate live replicas")
	var newer_effect := _hero_event(404, 4, true)
	var obsolete_effect := _hero_event(404, 3, false)
	_check(_deliver(replica, "event", newer_effect), "newer reliable hero effect should apply")
	_check(not _deliver(replica, "event", obsolete_effect), "out-of-contract older reliable event should fail closed")
	_check(replica.last_authoritative_event_id == 4 and int(presentation.hero_effect_counts_by_vfx.get("sword_shield_transform", 0)) == 1, "obsolete reliable effects must not replay presentation")
	_check(replica.stale_authoritative_event_count == 3, "replica diagnostics should count duplicate and obsolete reliable events")

	# Cross-channel ordering: an empty unreliable snapshot may arrive before a
	# reliable short-lived spawn. The spawn is still shown, then bounded by the
	# next complete snapshot.
	_check(_deliver(replica, "entity", _entity_snapshot(404, 200, [])), "new empty snapshot should apply")
	_check(_deliver(replica, "event", _entity_event(404, 5, AuthoritativeEvent.ENTITY_SPAWNED, 70)), "late cross-channel spawn should still be visible")
	_check(replica.entity(70) != null and presentation.entity_visuals.has(70), "late reliable spawn should not be swallowed by an earlier empty snapshot")
	_check(_deliver(replica, "entity", _entity_snapshot(404, 201, [])), "following complete snapshot should apply")
	_check(replica.entity(70) == null and not presentation.entity_visuals.has(70), "following complete snapshot should bound stale late-spawn lifetime")

	for node in [actor, presentation, replica]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	await process_frame
	if failures.is_empty():
		print("Network fault injection checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _deliver_schedule(replica: MatchReplica, schedule: Array) -> void:
	var ordered := schedule.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("at", 0)) < int(b.get("at", 0)))
	for delivery in ordered:
		_deliver(replica, str(delivery.get("channel", "")), delivery.get("packet", {}) as Dictionary)


func _deliver(replica: MatchReplica, channel: String, packet: Dictionary) -> bool:
	var accepted := false
	match channel:
		"actor": accepted = replica.apply_actor_snapshot(packet)
		"entity": accepted = replica.apply_entity_snapshot(packet)
		"event": accepted = replica.apply_authoritative_event(packet)
	if accepted:
		accepted_by_channel[channel] = int(accepted_by_channel.get(channel, 0)) + 1
	else:
		rejected_by_channel[channel] = int(rejected_by_channel.get(channel, 0)) + 1
	return accepted


func _actor_snapshot(match_id: int, tick: int, position: Vector3, hp: float) -> Dictionary:
	return {"match_id": match_id, "server_tick": tick, "actor": {
		"actor_id": 1, "position": [position.x, position.y, position.z], "velocity": [0.0, 0.0, 0.0],
		"facing": [1.0, 0.0], "hp": hp, "stamina": 100.0, "energy": 0.0,
		"cooldowns": {}, "statuses": [], "hero_runtime": {}, "defeated": false,
	}}


func _entity_snapshot(match_id: int, tick: int, entities: Array) -> Dictionary:
	return {"match_id": match_id, "server_tick": tick, "last_event_id": 0, "entities": entities}


func _projectile(entity_id: int, x: int) -> Dictionary:
	return {
		"entity_id": entity_id, "entity_kind": "projectile", "vfx_id": "sword_wave", "source_id": 1,
		"ability_id": "skill_q", "attack_id": entity_id, "position": [x, 500, 0], "direction": [10000, 0, 0],
		"radius": 1600, "color": [9000, 9500, 10000, 10000],
	}


func _entity_event(match_id: int, event_id: int, type: StringName, entity_id: int) -> Dictionary:
	var payload := {"entity_kind": "projectile", "vfx_id": "sword_wave"}
	if type == AuthoritativeEvent.ENTITY_SPAWNED:
		payload["initial_state"] = {
			"source_id": 1, "ability_id": "skill_q", "vfx_id": "sword_wave", "attack_id": entity_id,
			"position": [0.0, 0.05, 0.0], "direction": [1.0, 0.0, 0.0], "radius": 0.16,
		}
	return {"match_id": match_id, "event": AuthoritativeEvent.create(event_id, event_id, type, entity_id, payload).to_packet()}


func _hero_event(match_id: int, event_id: int, active: bool) -> Dictionary:
	return {"match_id": match_id, "event": AuthoritativeEvent.create(event_id, event_id, AuthoritativeEvent.HERO_EFFECT, 0, {
		"vfx_id": "sword_shield_transform", "source_id": 1, "active": active,
	}).to_packet()}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
