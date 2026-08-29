extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := ArenaWorld.new()
	arena.include_test_walls = false
	root.add_child(arena)
	var pathfinder := ArenaPathfinder.new()
	pathfinder.configure([])

	var nailoong := CombatActor.new()
	root.add_child(nailoong)
	nailoong.setup(Nailoong.create(), 1, "nailoong", CombatActor.Relation.SELF)
	nailoong.battle_id = 1
	nailoong.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	var nailoong_motor := CommandMotor.new()
	root.add_child(nailoong_motor)
	nailoong_motor.setup(nailoong, pathfinder)
	await _physics_frames(4)

	_check(not nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.BEGIN_ABILITY, "skill_e")), "BEGIN must reject a non-held ability")
	_check(not nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.CAST_ABILITY, "skill_w")), "CAST must reject a hold-to-channel ability")
	_check(nailoong.current_ability == null, "malformed begin/cast commands must not mutate combat state")
	_check(nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.BEGIN_ABILITY, "skill_w")), "BEGIN should start Nailoong fire breath")
	_check(nailoong_motor.continuous_session.state == ContinuousAbilitySession.State.HOLDING, "server should record one active held-ability session")
	_check(not nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.BEGIN_ABILITY, "skill_w")), "duplicate BEGIN must be rejected")
	_check(not nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.END_ABILITY, "skill_q")), "END must match the active held ability")
	_check(nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.END_ABILITY, "skill_w")), "matching END should release fire breath")
	await _physics_frames(10)
	_check(nailoong.current_ability == null and float(nailoong.cooldowns.get("skill_w", 0.0)) > 7.7, "fire-breath release should end once and start cooldown")
	_check(not nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.END_ABILITY, "skill_w")), "duplicate END must be rejected")

	nailoong.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	await _physics_frames(3)
	_check(nailoong_motor.apply_command(_ability_command(1, BattleCommand.Type.CAST_ABILITY, "skill_q")), "Nailoong roll should remain an instant CAST action")
	await _physics_frames(6)
	_check(nailoong_motor.apply_command(BattleCommand.create(1, BattleCommand.Type.CANCEL_ABILITY)), "CANCEL should stop the active roll")
	_check(nailoong.current_ability == null and float(nailoong.cooldowns.get("skill_q", 0.0)) > 4.9, "roll cancellation should start cooldown")
	_check(not nailoong_motor.apply_command(BattleCommand.create(1, BattleCommand.Type.CANCEL_ABILITY)), "duplicate CANCEL must be rejected")

	var shield_dog := CombatActor.new()
	root.add_child(shield_dog)
	shield_dog.setup(SwordShieldDog.create(), 2, "shield", CombatActor.Relation.ENEMY)
	shield_dog.battle_id = 2
	shield_dog.reset_runtime(Vector3(2.0, 0.05, 0.0))
	var shield_motor := CommandMotor.new()
	root.add_child(shield_motor)
	shield_motor.setup(shield_dog, pathfinder)
	await _physics_frames(4)
	_check(shield_motor.apply_command(_ability_command(2, BattleCommand.Type.BEGIN_ABILITY, "skill_q")), "BEGIN should start shield guard")
	_check(shield_motor.apply_command(_ability_command(2, BattleCommand.Type.END_ABILITY, "skill_q")), "an early key release should be accepted")
	_check(shield_motor.continuous_session.state == ContinuousAbilitySession.State.RELEASE_PENDING and shield_dog.current_ability != null, "shield guard must remain pending until its 0.5 second minimum")
	await _physics_frames(40)
	_check(shield_dog.current_ability == null and float(shield_dog.cooldowns.get("skill_q", 0.0)) > 1.8, "shield guard should end at the minimum duration and enter cooldown")

	shield_dog.reset_runtime(Vector3(2.0, 0.05, 0.0))
	await _physics_frames(3)
	_check(shield_motor.apply_command(_ability_command(2, BattleCommand.Type.BEGIN_ABILITY, "skill_q")), "shield guard should restart after reset")
	var move := BattleCommand.create(2, BattleCommand.Type.MOVE_TO, Vector3(3.5, 0.0, 0.0))
	_check(shield_motor.apply_command(move), "movement command should be accepted while guarding")
	_check(shield_motor.continuous_session.state == ContinuousAbilitySession.State.RELEASE_PENDING, "movement should request shield-guard release through the same session")
	await _physics_frames(40)
	_check(shield_dog.current_ability == null, "movement-triggered guard release should respect the minimum then finish")

	var stream := BattleCommandStream.new()
	root.add_child(stream)
	var runtime := BattleCommandRuntime.new()
	root.add_child(runtime)
	runtime.setup(stream, pathfinder)
	nailoong.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	await _physics_frames(3)
	var registered_motor := runtime.register_actor(nailoong)
	_check(registered_motor.apply_command(_ability_command(1, BattleCommand.Type.BEGIN_ABILITY, "skill_w")), "disconnect fixture should start a channel")
	runtime.unregister_actor(1)
	_check(nailoong.current_ability == null and not runtime.motors.has(1), "unregister/disconnect must force-clean the channel before removing its motor")

	for node in [runtime, stream, shield_motor, shield_dog, nailoong_motor, nailoong, arena]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	await _physics_frames(2)
	if failures.is_empty():
		print("Continuous ability session checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _ability_command(actor_id: int, type: BattleCommand.Type, ability_id: String) -> BattleCommand:
	var command := BattleCommand.create(actor_id, type, Vector3.ZERO)
	command.ability_id = ability_id
	return command


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
