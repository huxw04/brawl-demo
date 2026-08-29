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
	var target_definition := Nailoong.create()
	target_definition.max_hp = 1000.0
	target = CombatActor.new()
	root.add_child(target)
	target.setup(target_definition, 2, "测试目标", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	await _reset(Vector3.ZERO, Vector3(3.0, 0.0, 0.0))

	_check("chu_ying" in HeroCatalog.IDS and HeroCatalog.display_name("chu_ying") == "褚赢", "Chu Ying should be selectable")
	_check(hero.hero_runtime is ChuYingHeroRuntime, "Chu Ying should use the dedicated hero runtime")
	var initial_runtime_snapshot := hero.hero_runtime_snapshot()
	hero.chu_ying_q_charges = 0
	hero.chu_ying_q_recharge_remaining = 1.0
	hero.hero_runtime.apply_runtime_snapshot(initial_runtime_snapshot)
	_check(hero.chu_ying_q_charges == 3 and is_zero_approx(hero.chu_ying_q_recharge_remaining), "Chu Ying charge state should round-trip through the runtime snapshot seam")
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
	_check(hero.definition.status_bar_id.is_empty() and not hero.energy_label.visible, "Chu Ying should keep Q charge data without showing a white energy bar")

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
	await _frames(13)
	_check(get_nodes_in_group("chu_ying_board_rectangles").size() == 1, "W should render one small barrier-style rectangle")
	_check(get_nodes_in_group("chu_ying_light_walls").size() == 4, "W rectangle should have four vertically fading light walls")
	await _frames(22)
	_check(is_equal_approx(hp_before - target.hp, 10.0), "a pulled stone should deal ten damage along its path")
	_check(get_nodes_in_group("chu_ying_stones").is_empty(), "pulled stone should be consumed at the board")

	await _reset(Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	hero.set_ability_target(Vector3(5.5, 0.0, 0.0))
	_check(hero.try_ability("skill_e"), "E should begin its protected channel")
	await _frames(2)
	_check(hero.status_controller.has_tag("control_immune"), "E should grant super armor during its one-second startup")
	_check(get_nodes_in_group("chu_ying_teleport_charge").size() == 1 and get_nodes_in_group("concentration_rings").size() >= 3, "E startup should show a rotating floor circle and repeated inward focus rings")
	await _frames(60)
	_check(hero.global_position.x > 5.3 and hero.global_position.x < 5.7, "E should teleport to the selected point (actual %.2f)" % hero.global_position.x)
	_check(get_nodes_in_group("chu_ying_teleport_columns").size() == 2, "E should create one light column at both departure and arrival")
	await _frames(8)

	# Origin and the selected point are opposite corners of a 4-by-3 rectangle.
	await _reset(Vector3.ZERO, Vector3(3.6, 0.0, 1.2))
	hero.set_ability_target(Vector3(4.0, 0.0, 3.0))
	_check(hero.try_ability("ultimate"), "R should begin")
	await _frames(36)
	_check(target.global_position.y > 0.05 or target.hurt_remaining > 0.25, "R should knock up enemies inside after 0.5 seconds")
	var barriers := get_nodes_in_group("deterministic_combat_units").filter(func(node): return node is ChuYingBarrier)
	_check(barriers.size() == 1, "R should create one persistent barrier")
	if not barriers.is_empty():
		var barrier := barriers[0] as ChuYingBarrier
		_check(barrier.half_extents.is_equal_approx(Vector2(2.0, 1.5)) and barrier.trapped.has(target), "R should use the two points as opposite rectangle corners")
		_check(get_nodes_in_group("chu_ying_light_walls").size() == 4, "R should surround its rectangle with four vertically fading light walls")
		var move_stream := BattleCommandStream.new()
		root.add_child(move_stream)
		var move_pathfinder := ArenaPathfinder.new()
		move_pathfinder.configure([])
		var move_runtime := BattleCommandRuntime.new()
		root.add_child(move_runtime)
		move_runtime.setup(move_stream, move_pathfinder)
		move_runtime.register_actor(target)
		move_stream.submit(BattleCommand.create(target.battle_id, BattleCommand.Type.MOVE_TO, Vector3(6.0, 0.0, 3.0)))
		await _frames(90)
		var planar := target.global_position - barrier.global_position
		_check(absf(planar.x) < barrier.half_extents.x and absf(planar.z) < barrier.half_extents.y, "AI movement commands should remain clamped inside the rectangle")
		_check(barrier.remaining > 12.5, "barrier should persist while AI repeatedly tries to leave")
		move_runtime.stop_all()
		var safe_position := barrier.global_position + Vector3(0.25, 0.0, 0.2)
		safe_position.y = target.global_position.y
		target.global_position = safe_position
		await _frames(2)
		target.global_position = Vector3(barrier.global_position.x + barrier.half_extents.x + 1.5, target.global_position.y, barrier.global_position.z)
		target.velocity = Vector3(12.0, 0.0, 4.0)
		target.knockback_velocity = Vector3(18.0, 0.0, 7.0)
		await _frames(2)
		var restored_planar := Vector2(target.global_position.x, target.global_position.z)
		_check(restored_planar.distance_to(Vector2(safe_position.x, safe_position.z)) < 0.15, "an enemy knocked outside should return to its last valid interior position")
		_check(Vector2(target.knockback_velocity.x, target.knockback_velocity.z).length() < 0.01, "barrier recovery should clear outward knockback so collision recovery cannot eject the target again")
		target.reset_runtime(safe_position)
		target.set_ability_target(Vector3(barrier.global_position.x + barrier.half_extents.x + 3.0, 0.0, barrier.global_position.z))
		_check(target.try_ability("skill_e"), "a trapped Nailoong should still be allowed to attempt E")
		await _frames(50)
		var leap_planar := target.global_position - barrier.global_position
		_check(absf(leap_planar.x) < barrier.half_extents.x and absf(leap_planar.z) < barrier.half_extents.y, "Nailoong E authority endpoint should remain inside Chu Ying's barrier")
		var landing_waves := get_nodes_in_group("transient_combat_vfx").filter(func(node: Node) -> bool: return node.name == "NailoongLandingShockwave")
		_check(not landing_waves.is_empty() and (landing_waves.back() as Node3D).global_position.distance_to(target.global_position) < 0.25, "Nailoong E landing effect should use the confined authoritative endpoint")
		move_runtime.queue_free()
		move_stream.queue_free()

	var minimum_barrier := ChuYingBarrier.new()
	root.add_child(minimum_barrier)
	minimum_barrier.configure(hero, Vector3(8.0, 0.0, 8.0), Vector2(0.02, 0.08), 9999)
	_check(minimum_barrier.half_extents.is_equal_approx(Vector2(0.5, 0.5)), "R should enforce a minimum full size of 100 by 100 yards")
	minimum_barrier.queue_free()

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
