class_name CommandMotor
extends Node

const WAYPOINT_REACHED_DISTANCE := 0.16
const PASS_CORRIDOR_PADDING := 0.14

var actor: CombatActor
var pathfinder: ArenaPathfinder
var path := PackedVector3Array()
var path_index := 0
var destination := Vector3.ZERO
var resolved_destination := Vector3.ZERO
var direct_steering_destination := false
var direct_best_distance := INF
var movement_sample_position := Vector3.ZERO
var pending_basic := false
var pending_basic_target := Vector3.ZERO
var continuous_session: ContinuousAbilitySession


func setup(p_actor: CombatActor, p_pathfinder: ArenaPathfinder) -> void:
	actor = p_actor
	pathfinder = p_pathfinder
	movement_sample_position = actor.global_position
	continuous_session = ContinuousAbilitySession.new()
	continuous_session.setup(actor)


func apply_command(command: BattleCommand) -> bool:
	match command.type:
		BattleCommand.Type.MOVE_TO:
			continuous_session.release_for_movement()
			return set_destination(command.world_target, true)
		BattleCommand.Type.STOP:
			stop()
			return true
		BattleCommand.Type.BASIC_ATTACK:
			actor.cancel_nailoong_roll_for_command()
			pending_basic = true
			pending_basic_target = command.world_target
			_advance_pending_basic()
			return true
		BattleCommand.Type.CAST_ABILITY:
			pending_basic = false
			var cast_ability := actor.ability_by_id(command.ability_id)
			if cast_ability == null or cast_ability.hold_to_channel:
				return false
			var cast_target := command.world_target
			if cast_ability != null and cast_ability.face_move_direction_on_cast and command.direction.length_squared() > 0.001:
				actor.facing = Vector3(command.direction.x, 0.0, command.direction.z).normalized()
				cast_target = actor.global_position + actor.facing
			actor.set_ability_target(cast_target)
			_face_target(cast_target)
			stop()
			return actor.try_ability(command.ability_id)
		BattleCommand.Type.BEGIN_ABILITY:
			pending_basic = false
			var held_ability := actor.ability_by_id(command.ability_id)
			if held_ability == null or not held_ability.hold_to_channel:
				return false
			actor.set_ability_target(command.world_target)
			_face_target(command.world_target)
			stop()
			return continuous_session.begin(command.ability_id)
		BattleCommand.Type.END_ABILITY:
			return continuous_session.end(command.ability_id)
		BattleCommand.Type.ROLL:
			pending_basic = false
			if command.direction.length_squared() > 0.001:
				actor.facing = Vector3(command.direction.x, 0.0, command.direction.z).normalized()
				actor.set_move_intent(Vector2(actor.facing.x, actor.facing.z))
			return actor.try_roll()
		BattleCommand.Type.JUMP:
			pending_basic = false
			return actor.try_jump()
		BattleCommand.Type.CANCEL_ABILITY:
			return continuous_session.cancel_special()
	return false


func set_destination(target: Vector3, clear_pending := true) -> bool:
	if clear_pending:
		pending_basic = false
	destination = target
	if _is_nailoong_rolling():
		# Keep the steering target direct (a short A-star waypoint makes a
		# turning-limited roll orbit), but still use pathfinding to clamp clicks
		# outside the playable map to a valid endpoint.
		var endpoint_path := pathfinder.find_path(actor.global_position, target)
		if not endpoint_path.is_empty():
			destination = endpoint_path[endpoint_path.size() - 1]
		direct_steering_destination = true
		path = PackedVector3Array()
		path_index = 0
		movement_sample_position = actor.global_position
		var direct_offset := destination - actor.global_position
		direct_offset.y = 0.0
		actor.set_move_intent(Vector2(direct_offset.x, direct_offset.z).normalized() if direct_offset.length_squared() > 0.001 else Vector2.ZERO)
		direct_best_distance = direct_offset.length()
		resolved_destination = destination
		return direct_offset.length_squared() > 0.001
	direct_steering_destination = false
	direct_best_distance = INF
	path = pathfinder.find_path(actor.global_position, target)
	path_index = 1 if path.size() > 1 else 0
	resolved_destination = path[path.size() - 1] if not path.is_empty() else actor.global_position
	if path.is_empty():
		actor.set_move_intent(Vector2.ZERO)
	movement_sample_position = actor.global_position
	return not path.is_empty()


func advance_movement() -> void:
	continuous_session.refresh()
	if actor == null or actor.is_defeated:
		return
	var previous_position := movement_sample_position
	var current_position := actor.global_position
	movement_sample_position = current_position
	if pending_basic and _advance_pending_basic():
		return
	if direct_steering_destination:
		if _is_nailoong_rolling():
			var direct_offset := destination - actor.global_position
			direct_offset.y = 0.0
			var distance := direct_offset.length()
			var turning_radius := actor.definition.move_speed * 1.65 / TAU
			var closest_useful_distance := turning_radius + actor.definition.body_radius
			var passed_closest_approach := direct_best_distance <= closest_useful_distance and distance > direct_best_distance + 0.035
			direct_best_distance = minf(direct_best_distance, distance)
			if not _reached_or_crossed(destination, previous_position, current_position) and not passed_closest_approach:
				actor.set_move_intent(Vector2(direct_offset.x, direct_offset.z).normalized())
				return
			# Q keeps rolling under its own momentum, but no longer turns back at
			# the click and falls into a tight orbit around it.
			stop()
			return
		direct_steering_destination = false
		set_destination(destination, false)
	while path_index < path.size():
		var offset := path[path_index] - actor.global_position
		offset.y = 0.0
		if not _reached_or_crossed(path[path_index], previous_position, current_position):
			actor.set_move_intent(Vector2(offset.x, offset.z).normalized())
			return
		path_index += 1
	stop()


func stop(clear_pending := true) -> void:
	if clear_pending:
		pending_basic = false
	path = PackedVector3Array()
	path_index = 0
	direct_steering_destination = false
	direct_best_distance = INF
	if actor != null:
		actor.set_move_intent(Vector2.ZERO)
		movement_sample_position = actor.global_position


func force_cleanup_continuous_ability() -> bool:
	return continuous_session.force_cleanup() if continuous_session != null else false


func _advance_pending_basic() -> bool:
	if actor == null or not pending_basic:
		return false
	var basic := actor.ability_by_id("basic")
	if basic == null:
		pending_basic = false
		return false
	var flat_target := pending_basic_target
	flat_target.y = actor.global_position.y
	if actor.global_position.distance_to(flat_target) > basic.auto_target_radius:
		if path.is_empty() or destination.distance_squared_to(pending_basic_target) > 0.001:
			set_destination(pending_basic_target, false)
		return false
	_face_target(pending_basic_target)
	actor.set_ability_target(pending_basic_target)
	if basic.auto_target_radius > 0.0:
		actor.auto_face_nearest(basic.auto_target_radius)
	stop(false)
	if actor.try_ability("basic"):
		pending_basic = false
	return true


func _face_target(target: Vector3) -> void:
	var direction := target - actor.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		actor.facing = direction.normalized()


func _is_nailoong_rolling() -> bool:
	return actor != null and actor.current_ability != null and actor.current_ability.vfx_id == "nailoong_roll" and actor.ability_phase == "active"


func _reached_or_crossed(point: Vector3, previous_position: Vector3, current_position: Vector3) -> bool:
	var flat_point := Vector3(point.x, 0.0, point.z)
	var flat_current := Vector3(current_position.x, 0.0, current_position.z)
	if flat_current.distance_to(flat_point) <= WAYPOINT_REACHED_DISTANCE:
		return true
	var flat_previous := Vector3(previous_position.x, 0.0, previous_position.z)
	var travelled := flat_current - flat_previous
	var travelled_squared := travelled.length_squared()
	if travelled_squared <= 0.000001:
		return false
	var progress := clampf((flat_point - flat_previous).dot(travelled) / travelled_squared, 0.0, 1.0)
	var closest_on_step := flat_previous + travelled * progress
	var corridor := maxf(WAYPOINT_REACHED_DISTANCE, actor.definition.body_radius + PASS_CORRIDOR_PADDING)
	return progress > 0.0 and progress < 1.0 and closest_on_step.distance_to(flat_point) <= corridor
