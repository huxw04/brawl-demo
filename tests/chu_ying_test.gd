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
	hero.setup(ChuYing.create(), 1, "褚赢", CombatActor.Relation.SELF)
	hero.battle_id = 1
	var target_definition := PlaceholderHero.create()
	target_definition.max_hp = 1000.0
	target = CombatActor.new()
	root.add_child(target)
	target.setup(target_definition, 2, "测试目标", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	await _reset(Vector3.ZERO, Vector3(3.0, 0.0, 0.0))

	_check("chu_ying" in HeroCatalog.IDS and HeroCatalog.display_name("chu_ying") == "褚赢", "Chu Ying should be selectable")
	var texture := load("res://assets/heroes/chu_ying/sprites/chu_ying_idle_v1.png") as Texture2D
	var image := texture.get_image()
	_check(not image.is_empty() and image.get_pixel(0, 0).a < 0.05, "Chu Ying sprite should have a transparent corner")
	var basic := hero.definition.ability_by_id("basic")
	var q := hero.definition.ability_by_id("skill_q")
	var w := hero.definition.ability_by_id("skill_w")
	var e := hero.definition.ability_by_id("skill_e")
	var ultimate := hero.definition.ability_by_id("ultimate")
	_check(is_equal_approx(basic.target_required_range, 5.0) and basic.projectile_homing and is_equal_approx(basic.damage, 2.0), "basic should be a 500-yard homing stone for 2 damage")
	_check(is_equal_approx(q.hitbox_radius, 0.3) and is_equal_approx(q.cooldown, 0.5), "Q should use a 30-yard radius and 0.5 second cast interval")
	_check(is_equal_approx(w.cooldown, 8.0) and is_equal_approx(w.hitbox_radius, 0.5), "W should use an eight-second cooldown and 50-yard impact")
	_check(is_equal_approx(e.target_required_range, 10.0) and is_equal_approx(e.startup, 1.0), "E should teleport up to 1000 yards after one second")
	_check(is_equal_approx(ultimate.target_required_range, 5.0) and is_equal_approx(ultimate.cooldown, 30.0), "R should select within 500 yards and have 30 second cooldown")

	var hp_before := target.hp
	hero.set_ability_target(target.global_position)
	_check(hero.try_ability("basic"), "basic should cast at a target")
	await _frames(6)
	target.global_position = Vector3(3.0, 0.0, 0.35)
	await _frames(45)
	_check(is_equal_approx(hp_before - target.hp, 2.0), "homing basic should follow a moving target and deal two damage (actual %.2f)" % (hp_before - target.hp))

	await _reset(Vector3.ZERO, Vector3(2.0, 0.0, 0.0))
	_check(hero.chu_ying_q_charges == 3 and is_equal_approx(hero.energy, 3.0), "Q should start with three visible charges")
	hp_before = target.hp
	hero.set_ability_target(target.global_position)
	_check(hero.try_ability("skill_q"), "first Q charge should cast")
	_check(hero.chu_ying_q_charges == 2, "casting Q should consume one charge")
	_check(not hero.try_ability("skill_q"), "Q should respect its 0.5 second release interval")
	await _frames(38)
	_check(is_equal_approx(hp_before - target.hp, 5.0), "falling stone should deal five damage on landing")
	var stones := get_nodes_in_group("chu_ying_stones")
	_check(stones.size() == 1 and (stones[0] as ChuYingStone).ground_remaining > 9.0, "landed stone should remain for ten seconds")
	await _frames(270)
	_check(hero.chu_ying_q_charges == 3 and is_equal_approx(hero.energy, 3.0), "Q should restore one charge every five seconds")

	# The landed stone at x=2 flies through this target toward a board at x=4.
	target.global_position = Vector3(3.0, 0.0, 0.0)
	hp_before = target.hp
	hero.set_ability_target(Vector3(4.0, 0.0, 0.0))
	_check(hero.try_ability("skill_w"), "W should summon a board")
	await _frames(35)
	_check(is_equal_approx(hp_before - target.hp, 10.0), "a pulled stone should deal ten damage along its path")
	_check(get_nodes_in_group("chu_ying_stones").is_empty(), "pulled stone should be consumed at the board")

	await _reset(Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	hero.set_ability_target(Vector3(5.5, 0.0, 0.0))
	_check(hero.try_ability("skill_e"), "E should begin its protected channel")
	await _frames(2)
	_check(hero.status_controller.has_tag("control_immune"), "E should grant super armor during its one-second startup")
	await _frames(68)
	_check(hero.global_position.x > 5.3 and hero.global_position.x < 5.7, "E should teleport to the selected point (actual %.2f)" % hero.global_position.x)

	await _reset(Vector3.ZERO, Vector3(2.5, 0.0, 0.0))
	hero.set_ability_target(Vector3(4.0, 0.0, 0.0))
	_check(hero.try_ability("ultimate"), "R should begin")
	await _frames(36)
	_check(target.global_position.y > 0.05 or target.hurt_remaining > 0.25, "R should knock up enemies inside after 0.5 seconds")
	var barriers := get_nodes_in_group("deterministic_combat_units").filter(func(node): return node is ChuYingBarrier)
	_check(barriers.size() == 1, "R should create one persistent barrier")
	if not barriers.is_empty():
		var barrier := barriers[0] as ChuYingBarrier
		_check(is_equal_approx(barrier.radius, 2.0) and barrier.trapped.has(target), "R circle should use caster-to-point as its diameter and snapshot initial occupants")
		target.global_position = Vector3(6.0, 0.0, 0.0)
		await _frames(2)
		var planar := target.global_position - barrier.global_position
		planar.y = 0.0
		_check(planar.length() < barrier.radius, "trapped enemy should be clamped inside the barrier")
		_check(barrier.remaining > 14.0, "barrier should persist for fifteen seconds")

	var actors: Array[CombatActor] = [hero, target]
	var digest := BattleStateDigest.build(1, actors, BattleRng.new(12345))
	_check(not (digest.get("units", []) as Array).is_empty(), "deterministic digest should include persistent stones and barriers")

	hero.queue_free()
	target.queue_free()
	arena.queue_free()
	if failures.is_empty():
		print("Chu Ying checks passed.")
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
