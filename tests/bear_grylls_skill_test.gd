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
	hero.setup(BearGryllsJungler.create(), 1, "贝尔", CombatActor.Relation.SELF)
	hero.battle_id = 1
	var target_definition := PlaceholderHero.create()
	target_definition.max_hp = 400.0
	target = CombatActor.new()
	root.add_child(target)
	target.setup(target_definition, 2, "目标", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	# Do not let the two CharacterBody3D capsules enter their first physics tick
	# perfectly overlapped; collision recovery can otherwise launch the fixtures.
	hero.global_position = Vector3.ZERO
	target.global_position = Vector3(2.0, 0.0, 0.0)
	await _frames(4)

	var ranged := hero.definition.ability_by_id("basic")
	var melee := hero.definition.ability_variants["basic_melee"] as AbilityDefinition
	_check(is_equal_approx(ranged.auto_target_radius, 3.0), "basic search range should be 300 yards")
	_check(is_equal_approx(melee.hitbox_radius, 1.0), "melee branch should cover 100 yards")
	_check(hero.definition.ability_by_id("skill_q").cooldown == 8.0, "stealth cooldown should be 8 seconds")
	_check(hero.definition.ability_by_id("skill_e").projectile_speed * hero.definition.ability_by_id("skill_e").projectile_lifetime == 5.0, "grapple range should be 500 yards")

	await _reset(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3.LEFT)
	hero.set_ability_target(target.global_position)
	hero.facing = Vector3.RIGHT
	var ranged_hp := target.hp
	_check(hero.try_ability("basic"), "ranged basic should cast")
	_check(hero.current_ability.vfx_id == "bear_throw_knife", "targets beyond 100 yards should select thrown knife")
	_check(hero.sprite.texture == hero.definition.sprite_texture, "texture changes on the following visual tick")
	await _frames(2)
	_check(hero.sprite.texture == hero.definition.action_sprite_textures["bear_throw_knife"], "ranged highlight texture should be active")
	await _frames(24)
	_check(is_equal_approx(ranged_hp - target.hp, 11.0), "ranged knife should deal 11 damage (actual %.2f)" % (ranged_hp - target.hp))

	await _reset(Vector3.ZERO, Vector3(0.78, 0.0, 0.0), Vector3.LEFT)
	hero.set_ability_target(target.global_position)
	hero.facing = Vector3.RIGHT
	var melee_hp := target.hp
	_check(hero.try_ability("basic"), "melee basic should cast")
	_check(hero.current_ability.vfx_id == "bear_melee_knife", "targets within 100 yards should select melee slash")
	await _frames(18)
	_check(is_equal_approx(melee_hp - target.hp, 13.0), "melee slash should deal 13 damage")

	await _reset(Vector3.ZERO, Vector3(1.20, 0.0, 0.0), Vector3.LEFT)
	hero.set_ability_target(target.global_position)
	hero.facing = Vector3.RIGHT
	_check(hero.try_ability("basic"), "touching a target should cast basic")
	_check(hero.current_ability.vfx_id == "bear_melee_knife", "melee selection should measure horizontal reach to the target hurtbox")

	await _reset(Vector3.ZERO, Vector3(0.80, 0.0, 0.0), Vector3.RIGHT)
	var passive_hp := target.hp
	_check(target.receive_hit(hero, ranged, Vector3.RIGHT, 9001, 10.0), "direct passive test hit should land")
	_check(is_equal_approx(passive_hp - target.hp, 20.0), "damage from behind should be doubled")

	await _reset(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3.LEFT)
	_check(hero.try_ability("skill_q"), "stealth should cast")
	await _frames(8)
	_check(hero.status_controller.has_tag("stealth"), "Q should grant 15-second stealth")
	_check(not hero.is_visible_to(target.team), "enemy team should not see a stealthed Bear")
	_check(hero.sprite.modulate.a <= 0.21, "self stealth should render at 20 percent opacity")
	hero.set_ability_target(target.global_position)
	hero.facing = Vector3.RIGHT
	await _frames(10)
	_check(hero.try_ability("basic"), "attack after Q should cast")
	await _frames(10)
	_check(not hero.status_controller.has_tag("stealth"), "an active attack should break stealth")

	await _reset(Vector3.ZERO, Vector3(0.80, 0.0, 0.0), Vector3.LEFT)
	target.hp = 100.0
	var poison_expected := (target.definition.max_hp - target.hp) * 0.15
	_check(hero.try_ability("skill_w"), "poison mark should cast")
	await _frames(14)
	_check(target.status_controller.has_tag("stunned"), "poison mark should stun for one second")
	_check(is_equal_approx(target.hp, 100.0), "poison mark should have no immediate damage (actual HP %.2f)" % target.hp)
	_check(target.pending_damage_events.size() == 1, "poison mark should queue one delayed hit")
	await _frames(124)
	_check(absf(target.hp - (100.0 - poison_expected)) < 0.25, "poison should deal 15 percent missing HP after two seconds (actual HP %.2f)" % target.hp)

	await _reset(Vector3.ZERO, Vector3(3.0, 0.0, 0.0), Vector3.LEFT)
	_check(hero.try_ability("skill_q"), "stealth should be available before grapple")
	await _frames(14)
	hero.set_ability_target(target.global_position)
	hero.facing = Vector3.RIGHT
	var grapple_hp := target.hp
	_check(hero.try_ability("skill_e"), "grapple should cast")
	await _frames(9)
	_check(hero.status_controller.has_tag("stealth"), "grapple cast should not break stealth before it connects")
	_check(hero.sprite.texture == hero.definition.action_sprite_textures["bear_throw_knife"], "grapple release should reuse the ranged basic pose")
	await _frames(12)
	_check(not hero.status_controller.has_tag("stealth"), "grapple connection should break stealth")
	_check(hero.sprite.texture == hero.definition.action_sprite_textures["bear_grapple"], "grapple pull should use the braced flight pose")
	await _frames(7)
	_check(is_equal_approx(grapple_hp - target.hp, 6.0), "grapple should deal its small hit damage")
	_check(target.status_controller.has_tag("stunned"), "grapple actor hit should stun for 0.5 seconds")
	_check(hero.global_position.x > 0.30, "grapple actor hit should visibly pull Bear forward")

	await _reset(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), Vector3.RIGHT)
	hero.set_ability_target(target.global_position)
	hero.hp = 70.0
	var ambush_hp := target.hp
	_check(hero.try_ability("ultimate"), "ultimate should accept a target within 500 yards")
	await _frames(2)
	_check(hero.sprite.texture == hero.definition.action_sprite_textures["bear_ambush"], "ultimate highlight texture should be active")
	await _frames(12)
	_check(hero.global_position.x > 3.0 and hero.global_position.x < target.global_position.x, "ultimate should land behind a right-facing target")
	_check(is_equal_approx(ambush_hp - target.hp, 40.0), "R damage should double because it lands behind the target")

	await _reset(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), Vector3.RIGHT)
	hero.hp = 60.0
	target.hp = 30.0
	hero.set_ability_target(target.global_position)
	_check(hero.try_ability("ultimate"), "lethal ultimate should cast")
	await _frames(14)
	_check(target.is_defeated, "lethal ultimate should defeat the target")
	_check(is_equal_approx(hero.hp, 90.0), "hero kill should heal Bear for 30")
	_check(is_zero_approx(float(hero.cooldowns.get("ultimate", -1.0))), "R kill should immediately refresh R")

	await _reset(Vector3.ZERO, Vector3(5.4, 0.0, 0.0), Vector3.LEFT)
	hero.set_ability_target(target.global_position)
	_check(not hero.try_ability("ultimate"), "ultimate should reject targets beyond 500 yards")

	await _reset(Vector3.ZERO, Vector3(0.8, 0.0, 0.0), Vector3.LEFT)
	var dummy_basic := target.definition.ability_by_id("basic")
	_check(hero.receive_hit(target, dummy_basic, Vector3.LEFT, 9901, hero.definition.max_hp), "lethal damage should defeat Bear")
	await _frames(34)
	_check(hero.sprite.texture == hero.definition.sprite_texture, "death should use the neutral full-body sprite")
	_check(absf(absf(float(hero.sprite.get_meta("visual_angle", 0.0))) - PI * 0.5) < 0.04, "death should finish lying sideways on the ground")

	hero.queue_free()
	target.queue_free()
	arena.queue_free()
	if failures.is_empty():
		print("Bear Grylls skill checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _reset(hero_position: Vector3, target_position: Vector3, target_facing: Vector3) -> void:
	for effect in get_nodes_in_group("transient_combat_vfx"):
		effect.queue_free()
	for projectile in get_nodes_in_group("combat_projectiles"):
		projectile.queue_free()
	hero.reset_runtime(hero_position)
	target.reset_runtime(target_position)
	hero.facing = Vector3.RIGHT
	target.facing = target_facing
	# Teleports are synchronized with the physics server on the next tick. Waiting
	# also lets queued projectile/VFX deletions finish before the next isolated case.
	await _frames(2)


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
