class_name UtilityBot
extends Node

var actor: CombatActor
var target: CombatActor
var stream: BattleCommandStream
var rng: BattleRng
var think_remaining := 0.0
var strafe_sign := 1.0


func setup(p_actor: CombatActor, p_target: CombatActor, p_stream: BattleCommandStream, p_rng: BattleRng) -> void:
	actor = p_actor
	target = p_target
	stream = p_stream
	rng = p_rng


func _physics_process(delta: float) -> void:
	if actor == null or target == null or actor.is_defeated or target.is_defeated:
		return
	if not target.is_visible_to(actor.team):
		stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.STOP))
		return
	think_remaining -= delta
	if think_remaining > 0.0:
		return
	think_remaining = rng.randf_between(0.16, 0.28)
	var offset := target.global_position - actor.global_position
	offset.y = 0.0
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.01 else actor.facing
	if target.current_ability != null and target.ability_phase == "startup" and distance < 2.15 and actor.stamina >= actor.definition.max_stamina / 3.0:
		var roll := BattleCommand.create(actor.battle_id, BattleCommand.Type.ROLL)
		roll.direction = -direction
		stream.submit(roll)
		return
	if distance > 4.1:
		_submit_move(target.global_position)
		if actor.cooldown_ratio("skill_w") <= 0.0 and rng.randf_value() < 0.34:
			_submit_cast("skill_w", target.global_position)
	elif distance > 1.65:
		var tangent := Vector3(-direction.z, 0.0, direction.x) * strafe_sign
		_submit_move(target.global_position + tangent * 1.4)
		if rng.randf_value() < 0.18:
			strafe_sign *= -1.0
		if actor.energy >= 60.0 and rng.randf_value() < 0.28:
			_submit_cast("ultimate", target.global_position)
		elif actor.cooldown_ratio("skill_q") <= 0.0 and rng.randf_value() < 0.46:
			_submit_cast("skill_q", target.global_position)
	else:
		if actor.energy >= 60.0 and rng.randf_value() < 0.18:
			_submit_cast("ultimate", target.global_position)
		elif actor.cooldown_ratio("skill_e") <= 0.0 and rng.randf_value() < 0.2:
			_submit_cast("skill_e", target.global_position)
		elif actor.cooldown_ratio("skill_q") <= 0.0 and rng.randf_value() < 0.24:
			_submit_cast("skill_q", target.global_position)
		else:
			stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.BASIC_ATTACK, target.global_position))


func _submit_move(target_position: Vector3) -> void:
	stream.submit(BattleCommand.create(actor.battle_id, BattleCommand.Type.MOVE_TO, target_position))


func _submit_cast(ability_id: String, target_position: Vector3) -> void:
	var command := BattleCommand.create(actor.battle_id, BattleCommand.Type.CAST_ABILITY, target_position)
	command.ability_id = ability_id
	stream.submit(command)
