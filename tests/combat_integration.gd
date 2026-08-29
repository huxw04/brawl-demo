extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := ArenaWorld.new()
	arena.include_test_walls = false
	root.add_child(arena)
	var source := CombatActor.new()
	root.add_child(source)
	source.setup(PlaceholderHero.create(), 1, "source")
	_check(source.hero_runtime.get_script() == load("res://src/combat/hero_runtime/hero_runtime.gd"), "heroes without dedicated mechanics should use the transparent base HeroRuntime")
	source.global_position = Vector3(-2.0, 0.05, 0.0)
	source.facing = Vector3.RIGHT
	var target := CombatActor.new()
	root.add_child(target)
	target.setup(PlaceholderHero.create(), 2, "target")
	target.global_position = Vector3(-0.82, 0.05, 0.0)
	target.facing = Vector3.LEFT
	await _physics_frames(8)

	var initial_hp := target.hp
	_check(source.try_ability("basic"), "basic attack should start")
	await _physics_frames(28)
	_check(target.hp < initial_hp, "3D melee hitbox should damage the target")

	source.reset_runtime(Vector3(-3.0, 0.05, 1.4))
	target.reset_runtime(Vector3(2.0, 0.05, 1.4))
	source.facing = Vector3.RIGHT
	await _physics_frames(4)
	initial_hp = target.hp
	_check(source.try_ability("skill_w"), "projectile skill should start")
	await _physics_frames(80)
	_check(target.hp < initial_hp, "3D projectile should travel and damage the target")

	target.reset_runtime(Vector3(1.5, 0.05, 0.0))
	await _physics_frames(5)
	var hurtbox: Area3D = target.get_node("Hurtbox")
	var hurtbox_ground_y := hurtbox.global_position.y
	_check(target.try_jump(true), "jump should start while grounded")
	await _physics_frames(12)
	_check(target.height > 0.5, "CharacterBody3D should gain real world height")
	_check(hurtbox.global_position.y > hurtbox_ground_y + 0.5, "Hurtbox should rise with the jumping actor")

	target.reset_runtime(Vector3(1.5, 0.05, 0.0))
	await _physics_frames(5)
	target.set_move_intent(Vector2.LEFT)
	_check(target.try_roll(true), "roll should start")
	var basic := source.definition.ability_by_id("basic")
	_check(not target.receive_hit(source, basic, Vector3.RIGHT, 999), "roll i-frame should reject damage")

	source.reset_runtime(Vector3(-3.0, 0.05, 0.0))
	await _physics_frames(5)
	source.energy = 59.0
	_check(not source.try_ability("ultimate"), "ultimate should reject insufficient energy")
	source.energy = 60.0
	_check(source.try_ability("ultimate"), "ultimate should accept sufficient energy")

	# A real StaticBody3D wall must stop a projectile before it reaches the target.
	source.reset_runtime(Vector3(-3.0, 0.05, -1.8))
	target.reset_runtime(Vector3(2.0, 0.05, -1.8))
	source.facing = Vector3.RIGHT
	var wall := _test_wall(Vector3(-0.5, 1.0, -1.8), Vector3(0.35, 2.0, 2.0))
	root.add_child(wall)
	await _physics_frames(5)
	initial_hp = target.hp
	_check(source.try_ability("skill_w", true), "wall projectile test should start")
	await _physics_frames(80)
	_check(is_equal_approx(target.hp, initial_hp), "StaticBody3D wall should block the projectile")
	source.reset_runtime(Vector3(-3.0, 0.05, -1.8))
	source.set_move_intent(Vector2.RIGHT)
	await _physics_frames(70)
	_check(source.global_position.x < -0.92, "CharacterBody3D should stop at the wall")
	source.set_move_intent(Vector2.ZERO)

	# Stamina rules: roll costs exactly one third; ordinary movement and jumping regenerate normally.
	source.reset_runtime(Vector3(-3.0, 0.05, 2.4))
	await _physics_frames(5)
	var stamina_before := source.stamina
	source.set_move_intent(Vector2.RIGHT)
	_check(source.try_roll(), "roll should start with full stamina")
	_check(is_equal_approx(source.stamina, stamina_before - source.definition.max_stamina / 3.0), "roll should cost exactly one third stamina")
	source.reset_runtime(Vector3(-3.0, 0.05, 2.4))
	await _physics_frames(5)
	source.stamina = 50.0
	_check(source.try_jump(), "jump should start without stamina cost")
	await _physics_frames(12)
	_check(source.stamina > 50.0, "jumping should allow normal stamina regeneration")

	# Generic status pipeline checks without committing to a fixed hero mechanic list.
	source.reset_runtime(Vector3(-3.0, 0.05, 2.4))
	var slow := StatusEffectDefinition.new()
	slow.effect_id = "test_slow"
	slow.display_name = "Slow"
	slow.duration = 2.0
	slow.stat_multipliers = {"move_speed": 0.6}
	_check(source.apply_status(slow, target.battle_id), "slow status should apply")
	_check(is_equal_approx(source.status_controller.multiplier("move_speed"), 0.6), "slow multiplier should be exposed")
	var immunity := StatusEffectDefinition.new()
	immunity.effect_id = "test_immunity"
	immunity.duration = 2.0
	immunity.tags = PackedStringArray(["control_immune"])
	var stun := StatusEffectDefinition.new()
	stun.effect_id = "test_stun"
	stun.duration = 1.0
	stun.tags = PackedStringArray(["control", "stunned"])
	_check(source.apply_status(immunity), "control immunity should apply")
	_check(not source.apply_status(stun), "control immunity should reject control effects")
	source.status_controller.clear()
	_check(source.apply_status(stun), "stun should apply without immunity")
	_check(not source.try_ability("basic", true), "stun should block ability starts")
	source.status_controller.clear()
	var untargetable := StatusEffectDefinition.new()
	untargetable.effect_id = "test_untargetable"
	untargetable.duration = 1.0
	untargetable.tags = PackedStringArray(["untargetable"])
	source.apply_status(untargetable)
	_check(not source.receive_hit(target, basic, Vector3.LEFT, 1001), "untargetable should reject hits")
	source.status_controller.clear()
	var damage_over_time := StatusEffectDefinition.new()
	damage_over_time.effect_id = "test_dot"
	damage_over_time.duration = 0.28
	damage_over_time.tick_interval = 0.1
	damage_over_time.periodic_damage = 2.0
	initial_hp = source.hp
	source.apply_status(damage_over_time, target.battle_id)
	await _physics_frames(20)
	_check(source.hp <= initial_hp - 4.0, "periodic status should request repeated damage")

	source.queue_free()
	target.queue_free()
	wall.queue_free()
	arena.queue_free()
	if failures.is_empty():
		print("3D combat integration checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_wall(at_position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at_position
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
