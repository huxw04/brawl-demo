class_name CommandMotor
extends Node

var actor: CombatActor
var pathfinder: ArenaPathfinder
var path := PackedVector3Array()
var path_index := 0
var destination := Vector3.ZERO
var resolved_destination := Vector3.ZERO
var direct_steering_destination := false
var pending_basic := false
var pending_basic_target := Vector3.ZERO
var continuous_session: ContinuousAbilitySession


func setup(p_actor: CombatActor, p_pathfinder: ArenaPathfinder) -> void:
	actor = p_actor
	pathfinder = p_pathfinder
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
		direct_steering_destination = true
		path = PackedVector3Array()
		path_index = 0
		var direct_offset := target - actor.global_position
		direct_offset.y = 0.0
		actor.set_move_intent(Vector2(direct_offset.x, direct_offset.z).normalized() if direct_offset.length_squared() > 0.001 else Vector2.ZERO)
		resolved_destination = target
		return direct_offset.length_squared() > 0.001
	direct_steering_destination = false
	path = pathfinder.find_path(actor.global_position, target)
	path_index = 1 if path.size() > 1 else 0
	resolved_destination = path[path.size() - 1] if not path.is_empty() else actor.global_position
	if path.is_empty():
		actor.set_move_intent(Vector2.ZERO)
	return not path.is_empty()


func advance_movement() -> void:
	continuous_session.refresh()
	if actor == null or actor.is_defeated:
		return
	if pending_basic and _advance_pending_basic():
		return
	if direct_steering_destination:
		if _is_nailoong_rolling():
			var direct_offset := destination - actor.global_position
			direct_offset.y = 0.0
			if direct_offset.length() > 0.16:
				actor.set_move_intent(Vector2(direct_offset.x, direct_offset.z).normalized())
				return
			stop()
			return
		direct_steering_destination = false
		set_destination(destination, false)
	while path_index < path.size():
		var offset := path[path_index] - actor.global_position
		offset.y = 0.0
		if offset.length() > 0.16:
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
	if actor != null:
		actor.set_move_intent(Vector2.ZERO)


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
