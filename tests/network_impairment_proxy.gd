class_name NetworkImpairmentProxy
extends Node

## Test-only application-boundary network impairment. Production ENet settings
## stay untouched: this node intercepts the already decoded server messages on
## a client and deterministically delays, drops, duplicates, and reorders them.

var actor_received := 0
var actor_dropped := 0
var actor_delivered := 0
var actor_duplicated := 0
var entity_received := 0
var entity_dropped := 0
var entity_delivered := 0
var entity_duplicated := 0
var event_received := 0
var event_delivered := 0
var event_duplicated := 0
var maximum_queue_depth := 0

var _session: BrawlNetworkSession
var _match_scene: Node
var _frame := 0
var _queue: Array[Dictionary] = []


func setup(session: BrawlNetworkSession, match_scene: Node) -> void:
	_session = session
	_match_scene = match_scene
	_disconnect_direct_handlers()
	_session.state_snapshot_received.connect(_queue_actor_snapshot)
	_session.entity_snapshot_received.connect(_queue_entity_snapshot)
	_session.authoritative_event_received.connect(_queue_authoritative_event)


func restore_direct_delivery() -> void:
	if _session == null or _match_scene == null:
		return
	_disconnect_proxy_handlers()
	_queue.clear()
	_connect_direct_handlers()
	set_process(false)


func _process(_delta: float) -> void:
	_frame += 1
	for index in range(_queue.size() - 1, -1, -1):
		var item := _queue[index]
		if int(item.get("due_frame", 0)) > _frame:
			continue
		_queue.remove_at(index)
		var packet := item.get("packet", {}) as Dictionary
		match str(item.get("kind", "")):
			"actor":
				actor_delivered += 1
				_match_scene._on_state_snapshot(packet)
			"entity":
				entity_delivered += 1
				_match_scene._on_entity_snapshot(packet)
			"event":
				event_delivered += 1
				_match_scene._on_authoritative_event_received(packet)


func _queue_actor_snapshot(packet: Dictionary) -> void:
	actor_received += 1
	if _should_drop(actor_received):
		actor_dropped += 1
		return
	var delay := _snapshot_delay(actor_received)
	_enqueue("actor", packet, delay)
	if actor_received % 10 == 4:
		actor_duplicated += 1
		_enqueue("actor", packet, delay + 18)


func _queue_entity_snapshot(packet: Dictionary) -> void:
	entity_received += 1
	if _should_drop(entity_received + 3):
		entity_dropped += 1
		return
	var delay := _snapshot_delay(entity_received + 1)
	_enqueue("entity", packet, delay)
	if entity_received % 5 == 2:
		entity_duplicated += 1
		_enqueue("entity", packet, delay + 18)


func _queue_authoritative_event(packet: Dictionary) -> void:
	event_received += 1
	# Reliable ordered traffic is never dropped or reordered here. A duplicate
	# one frame later exercises event-id idempotence without violating order.
	_enqueue("event", packet, 7)
	if event_received % 2 == 1:
		event_duplicated += 1
		_enqueue("event", packet, 8)


func _enqueue(kind: String, packet: Dictionary, delay_frames: int) -> void:
	_queue.append({
		"kind": kind,
		"packet": packet.duplicate(true),
		"due_frame": _frame + delay_frames,
	})
	maximum_queue_depth = maxi(maximum_queue_depth, _queue.size())


func _should_drop(index: int) -> bool:
	return posmod(index * 7, 10) < 3


func _snapshot_delay(index: int) -> int:
	# At 60 fps this is 83–217 ms. Alternating long/short delays guarantees
	# that some later snapshots arrive before older snapshots.
	const DELAYS := [13, 5, 11, 6, 12, 7, 10, 5]
	return int(DELAYS[posmod(index - 1, DELAYS.size())])


func _disconnect_direct_handlers() -> void:
	if _session.state_snapshot_received.is_connected(_match_scene._on_state_snapshot):
		_session.state_snapshot_received.disconnect(_match_scene._on_state_snapshot)
	if _session.entity_snapshot_received.is_connected(_match_scene._on_entity_snapshot):
		_session.entity_snapshot_received.disconnect(_match_scene._on_entity_snapshot)
	if _session.authoritative_event_received.is_connected(_match_scene._on_authoritative_event_received):
		_session.authoritative_event_received.disconnect(_match_scene._on_authoritative_event_received)


func _connect_direct_handlers() -> void:
	if not _session.state_snapshot_received.is_connected(_match_scene._on_state_snapshot):
		_session.state_snapshot_received.connect(_match_scene._on_state_snapshot)
	if not _session.entity_snapshot_received.is_connected(_match_scene._on_entity_snapshot):
		_session.entity_snapshot_received.connect(_match_scene._on_entity_snapshot)
	if not _session.authoritative_event_received.is_connected(_match_scene._on_authoritative_event_received):
		_session.authoritative_event_received.connect(_match_scene._on_authoritative_event_received)


func _disconnect_proxy_handlers() -> void:
	if _session.state_snapshot_received.is_connected(_queue_actor_snapshot):
		_session.state_snapshot_received.disconnect(_queue_actor_snapshot)
	if _session.entity_snapshot_received.is_connected(_queue_entity_snapshot):
		_session.entity_snapshot_received.disconnect(_queue_entity_snapshot)
	if _session.authoritative_event_received.is_connected(_queue_authoritative_event):
		_session.authoritative_event_received.disconnect(_queue_authoritative_event)
