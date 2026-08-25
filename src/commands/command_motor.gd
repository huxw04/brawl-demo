class_name CommandMotor
extends Node

var actor: CombatActor
var pathfinder: ArenaPathfinder
var path := PackedVector3Array()
var path_index := 0
var destination := Vector3.ZERO
var pending_basic := false
var pending_basic_target := Vector3.ZERO


func setup(p_actor: CombatActor, p_pathfinder: ArenaPathfinder) -> void:
	actor = p_actor
	pathfinder = p_pathfinder


func apply_command(command: BattleCommand) -> void:
	match command.type:
		BattleCommand.Type.MOVE_TO:
			set_destination(command.world_target, true)
		BattleCommand.Type.STOP:
			stop()
		BattleCommand.Type.BASIC_ATTACK:
			actor.cancel_nailoong_roll_for_command()
			pending_basic = true
			pending_basic_target = command.world_target
			_advance_pending_basic()
		BattleCommand.Type.CAST_ABILITY:
			pending_basic = false
			actor.set_ability_target(command.world_target)
			_face_target(command.world_target)
			stop()
			actor.try_ability(command.ability_id)
		BattleCommand.Type.BEGIN_ABILITY:
			pending_basic = false
			actor.set_ability_target(command.world_target)
			_face_target(command.world_target)
			stop()
			actor.try_ability(command.ability_id)
		BattleCommand.Type.END_ABILITY:
			actor.release_held_ability(command.ability_id)
		BattleCommand.Type.ROLL:
			pending_basic = false
			if command.direction.length_squared() > 0.001:
				actor.facing = Vector3(command.direction.x, 0.0, command.direction.z).normalized()
				actor.set_move_intent(Vector2(actor.facing.x, actor.facing.z))
			actor.try_roll()
		BattleCommand.Type.JUMP:
			pending_basic = false
			actor.try_jump()
		BattleCommand.Type.CANCEL_ABILITY:
			actor.cancel_nailoong_roll_for_command()


func set_destination(target: Vector3, clear_pending := true) -> void:
	if clear_pending:
		pending_basic = false
	destination = target
	path = pathfinder.find_path(actor.global_position, target)
	path_index = 1 if path.size() > 1 else 0


func advance_movement() -> void:
	if actor == null or actor.is_defeated:
		return
	if pending_basic and _advance_pending_basic():
		return
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
	if actor != null:
		actor.set_move_intent(Vector2.ZERO)


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
