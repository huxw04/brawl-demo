class_name BrawlRespawnManager
extends Node

signal respawn_scheduled(actor: CombatActor, duration: float)
signal actor_respawned(actor: CombatActor, spawn_point_id: String)

const DEFAULT_RESPAWN_DURATION := 3.0
const DEFAULT_PROTECTION_DURATION := 1.5
const OCCUPIED_RADIUS := 1.4
const SAFE_POOL_SIZE := 3

var map_definition: BrawlMapDefinition
var battle_rng: BattleRng
var match_authority: MatchAuthority
var respawn_duration := DEFAULT_RESPAWN_DURATION
var protection_duration := DEFAULT_PROTECTION_DURATION
var actors_by_id: Dictionary = {}
var pending_respawns: Dictionary = {}
var last_spawn_ids: Dictionary = {}
var running := true


func setup(
		definition: BrawlMapDefinition,
		rng: BattleRng,
		authority: MatchAuthority,
		p_respawn_duration := DEFAULT_RESPAWN_DURATION,
		p_protection_duration := DEFAULT_PROTECTION_DURATION
) -> void:
	map_definition = definition
	battle_rng = rng
	match_authority = authority
	respawn_duration = maxf(0.01, p_respawn_duration)
	protection_duration = maxf(0.0, p_protection_duration)


func register_actor(actor: CombatActor, initial_spawn_id := "") -> void:
	if actor == null:
		return
	actors_by_id[actor.battle_id] = actor
	if not initial_spawn_id.is_empty():
		last_spawn_ids[actor.battle_id] = initial_spawn_id
	if not actor.defeated.is_connected(_on_actor_defeated):
		actor.defeated.connect(_on_actor_defeated)


func unregister_actor(actor_id: int) -> void:
	var actor := actors_by_id.get(actor_id) as CombatActor
	if actor != null and is_instance_valid(actor) and actor.defeated.is_connected(_on_actor_defeated):
		actor.defeated.disconnect(_on_actor_defeated)
	actors_by_id.erase(actor_id)
	pending_respawns.erase(actor_id)
	last_spawn_ids.erase(actor_id)


func _physics_process(delta: float) -> void:
	if not running:
		return
	var completed: Array[int] = []
	for actor_id_value in pending_respawns.keys():
		var actor_id := int(actor_id_value)
		var actor := actors_by_id.get(actor_id) as CombatActor
		if actor == null or not is_instance_valid(actor):
			completed.append(actor_id)
			continue
		var remaining := maxf(0.0, float(pending_respawns.get(actor_id, 0.0)) - delta)
		pending_respawns[actor_id] = remaining
		actor.respawn_remaining = remaining
		if remaining <= 0.0:
			completed.append(actor_id)
	for actor_id in completed:
		pending_respawns.erase(actor_id)
		var actor := actors_by_id.get(actor_id) as CombatActor
		if actor != null and is_instance_valid(actor) and actor.is_defeated:
			_respawn(actor)


func _on_actor_defeated(actor: CombatActor) -> void:
	if not running or actor == null or pending_respawns.has(actor.battle_id):
		return
	pending_respawns[actor.battle_id] = respawn_duration
	actor.respawn_remaining = respawn_duration
	respawn_scheduled.emit(actor, respawn_duration)
	_emit_rule_event(actor, "respawn_scheduled", {
		"duration": respawn_duration,
	})


func _respawn(actor: CombatActor) -> void:
	var spawn := _select_safe_spawn(actor)
	var position := spawn.get("position", Vector3.ZERO) as Vector3
	var spawn_id := str(spawn.get("id", "spawn_unknown"))
	actor.reset_runtime(position)
	actor.spawn_protection_remaining = protection_duration
	var toward_center := -Vector3(position.x, 0.0, position.z)
	if toward_center.length_squared() > 0.001:
		actor.facing = toward_center.normalized()
	last_spawn_ids[actor.battle_id] = spawn_id
	actor_respawned.emit(actor, spawn_id)
	_emit_rule_event(actor, "actor_respawned", {
		"spawn_point_id": spawn_id,
		"position": [position.x, position.y, position.z],
		"protection_duration": protection_duration,
	})


func _select_safe_spawn(actor: CombatActor) -> Dictionary:
	if map_definition == null or map_definition.spawn_points.is_empty():
		return {"id": "fallback", "position": Vector3.ZERO}
	var scored: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for spawn in map_definition.spawn_points:
		var candidate := spawn.duplicate(true)
		var position := candidate.get("position", Vector3.ZERO) as Vector3
		var minimum_distance_squared := INF
		var occupied := false
		for other_value in actors_by_id.values():
			var other := other_value as CombatActor
			if other == null or not is_instance_valid(other) or other == actor or other.is_defeated:
				continue
			var distance_squared := Vector2(position.x - other.global_position.x, position.z - other.global_position.z).length_squared()
			minimum_distance_squared = minf(minimum_distance_squared, distance_squared)
			if distance_squared < OCCUPIED_RADIUS * OCCUPIED_RADIUS:
				occupied = true
		if is_inf(minimum_distance_squared):
			minimum_distance_squared = 10000.0
		candidate["score"] = sqrt(minimum_distance_squared)
		fallback.append(candidate)
		if not occupied:
			scored.append(candidate)
	if scored.is_empty():
		scored = fallback
	var previous_id := str(last_spawn_ids.get(actor.battle_id, ""))
	if scored.size() > 1 and not previous_id.is_empty():
		var without_previous: Array[Dictionary] = []
		for candidate in scored:
			if str(candidate.get("id", "")) != previous_id:
				without_previous.append(candidate)
		if not without_previous.is_empty():
			scored = without_previous
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var pool_size := mini(SAFE_POOL_SIZE, scored.size())
	var total_weight := 0.0
	for index in range(pool_size):
		var distance := maxf(0.1, float(scored[index].get("score", 0.0)))
		total_weight += distance * distance
	var roll := battle_rng.randf_value() * total_weight if battle_rng != null else 0.0
	for index in range(pool_size):
		var distance := maxf(0.1, float(scored[index].get("score", 0.0)))
		roll -= distance * distance
		if roll <= 0.0:
			return scored[index]
	return scored[pool_size - 1]


func _emit_rule_event(actor: CombatActor, event_kind: String, extra: Dictionary) -> void:
	if match_authority == null:
		return
	var payload := extra.duplicate(true)
	payload["event_kind"] = event_kind
	payload["actor_id"] = actor.battle_id
	match_authority.emit_authoritative_event(AuthoritativeEvent.MATCH_RULE, actor.battle_id, payload)
