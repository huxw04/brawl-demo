extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := ArenaWorld.new()
	arena.include_test_walls = false
	root.add_child(arena)
	var hero := CombatActor.new()
	root.add_child(hero)
	hero.setup(SwordShieldDog.create(), 1, "刀盾狗", CombatActor.Relation.SELF)
	hero.battle_id = 1
	hero.global_position = Vector3.ZERO
	hero.facing = Vector3.RIGHT
	var target := CombatActor.new()
	root.add_child(target)
	var dummy_definition := PlaceholderHero.create()
	dummy_definition.max_hp = 500.0
	target.setup(dummy_definition, 2, "target", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	target.global_position = Vector3(1.0, 0.0, 0.0)
	await _frames(4)
	var sword_layer := hero.visual_layer_sprites.get("shield_dog_sword") as Sprite3D
	var shield_layer := hero.visual_layer_sprites.get("shield_dog_shield") as Sprite3D
	_check(absf(float(sword_layer.get_meta("visual_angle", 0.0)) - 1.50) < 0.03, "idle sword should point vertically upward")
	_check(sword_layer.position.z > shield_layer.position.z, "sword should stay in front of the shield")

	_check(is_equal_approx(hero.definition.ability_by_id("basic").hitbox_radius, 1.80), "base basic should be 180 yards")
	_check(is_zero_approx(hero.definition.ability_by_id("basic").knockback), "base basic should not knock back")
	_check(hero.try_ability("skill_q", true), "hold block should begin")
	hero.release_held_ability("skill_q")
	await _frames(18)
	_check(hero.current_ability != null, "early release should respect the 0.5 second minimum")
	await _frames(25)
	_check(hero.current_ability == null and float(hero.cooldowns.get("skill_q", 0.0)) > 1.5, "block cooldown should begin when the guard ends")

	hero.cooldowns["skill_q"] = 0.0
	_check(hero.try_ability("skill_q", true), "front block should restart")
	await _frames(8)
	var attack := target.definition.ability_by_id("basic")
	var hp_before := hero.hp
	_check(not hero.receive_hit(target, attack, Vector3.LEFT, 100, 10.0), "front attack should be blocked")
	_check(is_equal_approx(hero.hp, hp_before), "blocked attack should deal no damage")
	target.global_position = Vector3(-1.0, 0.0, 0.0)
	_check(hero.receive_hit(target, attack, Vector3.RIGHT, 101, 10.0), "rear attack should bypass the shield")
	hero.reset_runtime(Vector3.ZERO)
	target.reset_runtime(Vector3(1.2, 0.0, 0.0))
	hero.facing = Vector3.RIGHT
	await _frames(4)

	var target_hp := target.hp
	_check(hero.try_ability("skill_w", true), "heavy chop should start")
	_check(hero.status_controller.has_tag("control_immune"), "heavy chop charge should grant control immunity")
	await _frames(20)
	_check(sword_layer.scale.x > 1.45, "heavy chop sword should visibly lengthen during startup")
	await _frames(25)
	_check(is_equal_approx(target_hp - target.hp, 15.0), "heavy chop first pulse should deal 15")
	_check(hero.current_ability == null, "heavy chop actor action should end immediately after the first slam")
	# Moving after the slam must not drag the delayed ground explosion along.
	hero.global_position = Vector3(-4.0, 0.0, 0.0)
	await _frames(87)
	_check(is_equal_approx(target_hp - target.hp, 35.0), "heavy chop world-anchored second hit should raise total damage to 35")

	hero.reset_runtime(Vector3.ZERO)
	target.reset_runtime(Vector3(0.8, 0.0, 0.0))
	hero.facing = Vector3.RIGHT
	await _frames(4)
	_check(hero.try_ability("skill_e", true), "shield bash should start")
	var bash_start_x := target.global_position.x
	await _frames(16)
	_check(not target.status_controller.has_tag("stunned"), "shield bash should start knockback before stun")
	_check(target.knockback_velocity.x > 0.0 or target.global_position.x > bash_start_x, "shield bash should apply forward knockback first")
	await _frames(10)
	_check(target.status_controller.has_tag("stunned"), "shield bash should stun for one second")

	hero.reset_runtime(Vector3.ZERO)
	target.reset_runtime(Vector3(1.0, 0.0, 0.0))
	hero.facing = Vector3.RIGHT
	hero.energy = hero.definition.max_energy
	await _frames(4)
	_check(hero.try_ability("ultimate"), "full resource should cast transformation")
	await _frames(42)
	_check(hero.transformed, "ultimate should enter muscular form")
	_check(hero.definition.sprite_pose_clips.has("transformed_walk") and hero.definition.sprite_pose_clips.has("transformed_basic") and hero.definition.sprite_pose_clips.has("transformed_slam"), "muscular form should provide walk, basic, and slam keyframe clips")
	_check(is_equal_approx(hero.ability_by_id("basic").hitbox_radius, 2.80), "muscular basic should be 280 yards")
	_check(hero.ability_by_id("skill_q").disabled, "muscular form should disable Q")
	var transformed_w := hero.ability_by_id("skill_w")
	_check(is_equal_approx(transformed_w.dash_distance, 0.80), "muscular W should dash 80 yards")
	_check(transformed_w.knockback > 0.0, "muscular W should be the transformed knockback attack")
	var transformed_e := hero.ability_by_id("skill_e")
	_check(transformed_e.vfx_id == "swole_slam" and is_equal_approx(transformed_e.hitbox_radius, 2.65), "muscular E should be the circular ground slam")
	await _frames(16)
	target.global_position = Vector3(5.0, 0.0, 0.0)
	hero.facing = Vector3.RIGHT
	var dash_start_x := hero.global_position.x
	_check(hero.try_ability("skill_w", true), "muscular W dash should start")
	await _frames(6)
	var mid_dash_distance := hero.global_position.x - dash_start_x
	_check(mid_dash_distance > 0.05 and mid_dash_distance < 0.75, "muscular W should visibly travel instead of teleporting")
	await _frames(16)
	var final_dash_distance := hero.global_position.x - dash_start_x
	_check(absf(final_dash_distance - 0.80) < 0.08, "muscular W should travel 80 yards (got %.3f)" % final_dash_distance)
	hero.hp = 100.0
	var transformed_basic := hero.ability_by_id("basic")
	hero.on_ability_hit(transformed_basic, 10.0)
	_check(is_equal_approx(hero.hp, 103.0), "muscular attacks should heal 30 percent of damage")
	var camera_basis := arena.camera.global_basis.orthonormalized()
	hero.global_position.x = -5.0
	await _frames(1)
	var left_basis := hero.sprite.global_basis.orthonormalized()
	hero.global_position.x = 5.0
	await _frames(1)
	var right_basis := hero.sprite.global_basis.orthonormalized()
	_check(left_basis.x.dot(right_basis.x) > 0.999 and left_basis.y.dot(right_basis.y) > 0.999, "2D cutout orientation should not twist across the camera view")
	_check(right_basis.z.dot(camera_basis.z) > 0.999, "2D cutout should copy the fixed camera orientation")
	await _frames(490)
	_check(not hero.transformed, "muscular form should end after eight seconds")
	_check(float(hero.cooldowns.get("ultimate", 0.0)) > 29.0, "ultimate cooldown should begin after reverting")

	hero.queue_free()
	target.queue_free()
	arena.queue_free()
	if failures.is_empty():
		print("Sword-and-shield dog checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
