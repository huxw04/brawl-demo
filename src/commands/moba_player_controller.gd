class_name MobaPlayerController
extends Node

signal targeting_changed(ability_id: String)
signal movement_requested(world_target: Vector3)

var actor: CombatActor
var arena: ArenaWorld
var stream: Node
var pending_ability := ""
var mouse_ground := Vector3.ZERO
var movement_only := false
var held_input_ability := ""


func setup(p_actor: CombatActor, p_arena: ArenaWorld, p_stream: Node, p_movement_only := false) -> void:
	actor = p_actor
	arena = p_arena
	stream = p_stream
	movement_only = p_movement_only


func _unhandled_input(event: InputEvent) -> void:
	if actor == null:
		return
	if actor.is_defeated:
		pending_ability = ""
		held_input_ability = ""
		targeting_changed.emit("")
		return
	if event is InputEventMouseMotion:
		mouse_ground = arena.screen_to_ground(event.position)
	elif event is InputEventMouseButton and event.pressed:
		mouse_ground = arena.screen_to_ground(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			pending_ability = ""
			targeting_changed.emit("")
			movement_requested.emit(mouse_ground)
			stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.MOVE_TO, mouse_ground))
		elif event.button_index == MOUSE_BUTTON_LEFT and not movement_only:
			if pending_ability.is_empty():
				stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.BASIC_ATTACK, mouse_ground))
			else:
				var command := BattleCommand.create(actor.battle_id, BattleCommand.Type.CAST_ABILITY, mouse_ground)
				command.ability_id = pending_ability
				stream.submit(command)
				pending_ability = ""
				targeting_changed.emit("")
	elif event is InputEventKey and not event.echo:
		if movement_only:
			if event.pressed:
				match event.keycode:
					KEY_S: stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.STOP))
					KEY_SHIFT: _submit_roll()
					KEY_SPACE: stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.JUMP))
			return
		if event.pressed:
			match event.keycode:
				KEY_S: stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.STOP))
				KEY_Q: _press_ability("skill_q")
				KEY_W: _press_ability("skill_w")
				KEY_E: _press_ability("skill_e")
				KEY_R: _press_ability("ultimate")
				KEY_SHIFT: _submit_roll()
				KEY_SPACE: stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.JUMP))
		else:
			match event.keycode:
				KEY_Q: _release_ability("skill_q")
				KEY_W: _release_ability("skill_w")
				KEY_E: _release_ability("skill_e")
				KEY_R: _release_ability("ultimate")


func _press_ability(id: String) -> void:
	var ability := actor.ability_by_id(id)
	if ability == null or ability.disabled or not actor.can_select_ability(id):
		pending_ability = ""
		targeting_changed.emit("")
		return
	if ability.hold_to_channel:
		pending_ability = ""
		held_input_ability = id
		targeting_changed.emit("")
		var command := BattleCommand.create(actor.battle_id, BattleCommand.Type.BEGIN_ABILITY, actor.global_position + actor.facing)
		command.ability_id = id
		stream.submit(command)
		return
	_select_ability(id)


func _release_ability(id: String) -> void:
	var ability := actor.ability_by_id(id)
	if ability == null or not ability.hold_to_channel or held_input_ability != id:
		return
	held_input_ability = ""
	var command := BattleCommand.create(actor.battle_id, BattleCommand.Type.END_ABILITY)
	command.ability_id = id
	stream.submit(command)


func _select_ability(id: String) -> void:
	var ability := actor.ability_by_id(id)
	if ability == null or ability.disabled or not actor.can_select_ability(id):
		pending_ability = ""
		targeting_changed.emit("")
		return
	if ability.requires_aim_confirmation and actor.current_ability != null and actor.current_ability.vfx_id == "nailoong_roll":
		stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.CANCEL_ABILITY))
	if ability != null and not ability.requires_aim_confirmation:
		pending_ability = ""
		targeting_changed.emit("")
		var command := BattleCommand.create(actor.battle_id, BattleCommand.Type.CAST_ABILITY, actor.global_position)
		command.ability_id = id
		if ability.face_move_direction_on_cast:
			var move_direction := Vector3(actor.move_intent.x, 0.0, actor.move_intent.y)
			command.direction = move_direction.normalized() if move_direction.length_squared() > 0.001 else actor.facing
		stream.submit(command)
		return
	pending_ability = "" if pending_ability == id else id
	targeting_changed.emit(pending_ability)


func _submit_roll() -> void:
	var command := BattleCommand.create(actor.battle_id, BattleCommand.Type.ROLL)
	var direction := Vector3(actor.move_intent.x, 0.0, actor.move_intent.y)
	command.direction = direction.normalized() if direction.length_squared() > 0.001 else actor.facing
	stream.submit(command)
