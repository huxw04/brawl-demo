extends SceneTree

var failures: Array[String] = []
var arena: ArenaWorld
var hero: CombatActor
var target: CombatActor


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	arena = ArenaWorld.new()
	arena.include_test_walls = false
	root.add_child(arena)
	hero = CombatActor.new()
	root.add_child(hero)
	hero.setup(Nailoong.create(), 1, "奶龙", CombatActor.Relation.SELF)
	hero.battle_id = 1
	var target_definition := PlaceholderHero.create()
	target_definition.max_hp = 500.0
	target = CombatActor.new()
	root.add_child(target)
	target.setup(target_definition, 2, "测试目标", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	hero.global_position = Vector3.ZERO
	target.global_position = Vector3(3.0, 0.0, 0.0)
	await _frames(4)

	_check(HeroCatalog.display_name("bear_grylls_jungler") == "贝爷", "Bear display name should be shortened")
	_check(HeroCatalog.display_name("nailoong") == "奶龙", "Nailoong should appear in the hero catalog")
	_check("nailoong" in HeroCatalog.IDS, "Nailoong id should be selectable")
	var sprite_texture := load("res://assets/heroes/nailoong/sprites/nailoong_idle_v1.png") as Texture2D
	var image := sprite_texture.get_image()
	_check(not image.is_empty() and image.get_pixel(0, 0).a < 0.05, "approved Nailoong sprite should have a transparent corner")

	var basic := hero.definition.ability_by_id("basic")
	var roll := hero.definition.ability_by_id("skill_q")
	var fire := hero.definition.ability_by_id("skill_w")
	var leap := hero.definition.ability_by_id("skill_e")
	var laugh := hero.definition.ability_by_id("ultimate")
	_check(is_equal_approx(basic.hitbox_radius, 2.2) and is_equal_approx(basic.damage, 10.0), "tail basic should use 220-yard range and 10 damage")
	_check(is_equal_approx(roll.active, 6.0) and is_equal_approx(roll.cooldown, 5.0), "roll duration and cooldown should match design")
	_check(is_equal_approx(fire.maximum_hold_duration, 5.0) and is_equal_approx(fire.move_speed_multiplier_during_cast, 0.5), "fire channel should last five seconds at half movement speed")
	_check(is_equal_approx(leap.hitbox_radius, 1.5), "leap landing radius should be 150 yards")
	_check(is_equal_approx(laugh.cooldown, 30.0), "laugh cooldown should be 30 seconds")

	await _reset(Vector3.ZERO, Vector3(1.75, 0.0, 0.0))
	hero.facing = Vector3.RIGHT
	var basic_hp := target.hp
	_check(hero.try_ability("basic"), "tail basic should cast")
	await _frames(22)
	_check(is_equal_approx(basic_hp - target.hp, 10.0), "tail basic should deal 10 damage")

	await _reset(Vector3(5.8, 0.0, 0.0), Vector3.ZERO)
	hero.facing = Vector3.RIGHT
	_check(hero.try_ability("skill_q"), "roll should start")
	await _frames(8)
	var hp_before_reduction := hero.hp
	_check(hero.receive_hit(target, target.definition.ability_by_id("basic"), Vector3.LEFT, 7101, 10.0), "roll damage-reduction test hit should land")
	_check(is_equal_approx(hp_before_reduction - hero.hp, 8.0), "roll should reduce incoming damage by 20 percent")
	_check(hero.current_ability != null, "ordinary damage should not interrupt roll (definition flag %s)" % roll.uninterruptible_by_damage)
	await _frames(22)
	_check(hero.nailoong_roll_direction.x < -0.1, "roll should reflect from an arena wall (position %s, direction %s)" % [hero.global_position, hero.nailoong_roll_direction])
	_check(not hero.try_ability("skill_q"), "pressing Q during roll should only cancel it")
	_check(hero.current_ability == null and float(hero.cooldowns.get("skill_q", 0.0)) > 4.8, "cancelled roll should enter five-second cooldown")

	await _reset(Vector3.ZERO, Vector3(3.0, 0.0, 0.0))
	hero.facing = Vector3.RIGHT
	_check(hero.try_ability("skill_q"), "steering test roll should start")
	await _frames(6)
	hero.set_move_intent(Vector2(0.0, -1.0))
	await _frames(60)
	var steered_angle := Vector3.RIGHT.angle_to(hero.nailoong_roll_direction)
	_check(steered_angle > 0.42 and steered_angle < 0.58, "roll steering should be capped near 0.5 rad per second (actual %.3f)" % steered_angle)

	await _reset(Vector3.ZERO, Vector3(2.2, 0.0, 0.0))
	hero.facing = Vector3.RIGHT
	_check(hero.try_ability("skill_q"), "roll should start before another skill")
	await _frames(8)
	_check(hero.try_ability("skill_w"), "W should cancel roll and execute immediately")
	await _frames(66)
	_check(hero.current_ability != null and hero.current_ability.vfx_id == "nailoong_fire_breath", "fire breath should be channeling")
	hero.set_move_intent(Vector2(0.0, -1.0))
	await _frames(2)
	_check(hero.facing.z < -0.9, "moving during fire breath should update its facing")
	_check(hero.nailoong_fire_emit_index >= 8, "fire breath should emit about ten projectiles per second")
	var projectiles := get_nodes_in_group("combat_projectiles")
	if not projectiles.is_empty():
		var projectile := projectiles[0] as CombatProjectile
		_check(projectile.current_speed < fire.projectile_speed, "fire projectiles should decelerate while moving")
	hero.release_held_ability("skill_w")
	await _frames(3)
	_check(hero.current_ability == null and float(hero.cooldowns.get("skill_w", 0.0)) > 7.8, "releasing W should end channel and begin cooldown")

	await _reset(Vector3.ZERO, Vector3(2.55, 0.0, 0.0))
	hero.set_ability_target(Vector3(3.0, 0.0, 0.0))
	hero.facing = Vector3.RIGHT
	var leap_hp := target.hp
	_check(hero.try_ability("skill_e"), "leap should cast")
	await _frames(20)
	_check(hero.global_position.y > 0.45, "leap should visibly leave the ground")
	await _frames(28)
	_check(hero.global_position.x > 2.65 and hero.global_position.x <= 3.05, "leap should travel no farther than 300 yards")
	_check(is_equal_approx(leap_hp - target.hp, 10.0), "leap landing should deal 10 damage")
	_check(target.status_controller.multiplier("move_speed") <= 0.81, "leap landing should apply 20 percent slow")

	await _reset(Vector3.ZERO, Vector3(3.0, 0.0, 0.0))
	hero.hp = 60.0
	_check(hero.try_ability("ultimate"), "laugh ultimate should cast")
	await _frames(55)
	_check(is_equal_approx(hero.hp, 60.0), "laugh should not heal before its one-second windup finishes")
	await _frames(320)
	_check(is_equal_approx(hero.hp, 140.0), "laugh should heal 8 health ten times over five seconds")

	hero.queue_free()
	target.queue_free()
	arena.queue_free()
	if failures.is_empty():
		print("Nailoong checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _reset(hero_position: Vector3, target_position: Vector3) -> void:
	for effect in get_nodes_in_group("transient_combat_vfx"):
		effect.queue_free()
	for projectile in get_nodes_in_group("combat_projectiles"):
		projectile.queue_free()
	hero.reset_runtime(hero_position)
	target.reset_runtime(target_position)
	hero.facing = Vector3.RIGHT
	target.facing = Vector3.LEFT
	await _frames(2)


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
