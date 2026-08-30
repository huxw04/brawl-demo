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
	hero.setup(CheemsSamurai.create(), 1, "cheems", CombatActor.Relation.SELF)
	hero.battle_id = 1
	_check(hero.hero_runtime is CheemsHeroRuntime, "Cheems should use the dedicated authoritative HeroRuntime")
	var initial_runtime := hero.hero_runtime.runtime_snapshot()
	hero.basic_combo_step = 2
	hero.weapon_drawn = true
	hero.hero_runtime.apply_runtime_snapshot(initial_runtime)
	_check(hero.basic_combo_step == 0 and not hero.weapon_drawn, "Cheems runtime snapshot should restore combo and weapon state")
	hero.global_position = Vector3(-2.0, 0.05, 0.0)
	var target := CombatActor.new()
	root.add_child(target)
	target.setup(PlaceholderHero.create(), 2, "target", CombatActor.Relation.ENEMY)
	target.battle_id = 2
	target.global_position = Vector3(-0.6, 0.05, 0.0)
	await _physics_frames(6)

	_check(hero.definition.sprite_texture != null, "Cheems sprite should be loadable")
	hero.facing = Vector3.RIGHT
	await _physics_frames(1)
	var back_blade := hero.visual_layer_sprites.get("katana_back") as Sprite3D
	var camera_direction := (arena.camera.global_position - back_blade.global_position).normalized()
	_check(back_blade.global_basis.z.dot(camera_direction) > 0.9, "katana front face should point toward the camera")
	_check(back_blade.flip_h == hero.sprite.flip_h, "katana and body should share the same facing mirror")
	_check(back_blade.position.x < 0.0, "right-facing idle katana should sit behind the actor")
	hero.facing = Vector3.LEFT
	await _physics_frames(1)
	_check(back_blade.flip_h == hero.sprite.flip_h, "left-facing katana and body should share the same mirror")
	_check(back_blade.position.x > 0.0, "left-facing idle katana should sit behind the actor")
	var basic_definition := hero.definition.ability_by_id("basic")
	_check(is_equal_approx(basic_definition.hitbox_radius, 2.2), "basic judgment radius should be doubled to 2.2 world units")
	_check(is_zero_approx(basic_definition.knockback), "Cheems basic should not knock back")
	var q_definition := hero.definition.ability_by_id("skill_q")
	_check(is_equal_approx(q_definition.projectile_speed * q_definition.projectile_lifetime, 6.0), "Q should travel exactly six grid cells")
	_check(q_definition.knockback > 0.0, "Cheems Q should retain its small knockback")
	_check(is_zero_approx(hero.definition.ability_by_id("skill_w").knockback) and is_zero_approx(hero.definition.ability_by_id("skill_e").knockback), "Cheems W and E should not knock back")
	var ultimate_definition := hero.definition.ability_by_id("ultimate")
	_check(is_equal_approx(ultimate_definition.hitbox_radius, 2.0), "ultimate radius should be 200 yards / two world units")
	_check(is_equal_approx(ActorPresentation.ACTION_SWORD_BODY_INSET, 0.30), "W, E, and R sword poses should share a 30-yard body inset")
	hero.facing = Vector3.LEFT
	_check(hero.auto_face_nearest(2.35), "basic auto-target should acquire in a full circle")
	_check(hero.facing.x > 0.9, "auto-target should turn toward the acquired target")
	var hat_layer := hero.visual_layer_sprites.get("hat") as Sprite3D
	var hat_base_x := 0.10 if hero.facing.x >= 0.0 else -0.10
	var hat_base_z := 0.025

	hero.energy = 99.0
	_check(not hero.try_ability("ultimate"), "ultimate should require a full energy bar")
	hero.energy = 100.0
	_check(hero.try_ability("ultimate"), "ultimate should unlock at full energy")
	_check(hero.get_tree().get_nodes_in_group("concentration_rings").size() >= 3, "ultimate startup should repeatedly contract white rings across its range")
	await _physics_frames(3)
	_check(hero.status_controller.has_tag("control_immune"), "ultimate should grant control immunity immediately")
	_check(target.status_controller.has_visual("slow"), "ultimate startup should immediately slow enemies inside the circle")
	_check(not hero.status_controller.has_tag("untargetable"), "ultimate should remain targetable during its startup")
	await _physics_frames(32)
	_check(hero.status_controller.has_tag("untargetable"), "ultimate second stage should become untargetable when an enemy is in range")
	var saw_depth_motion := false
	for _index in range(18):
		await physics_frame
		if absf(hero.sprite.position.z) > 0.08:
			saw_depth_motion = true
	_check(saw_depth_motion, "ultimate body should move along random ground-plane lines rather than only left and right")
	_check(is_equal_approx(hat_layer.position.x - hat_base_x, hero.sprite.position.x) and is_equal_approx(hat_layer.position.z - hat_base_z, hero.sprite.position.z), "ultimate hat and body should share the same two-dimensional active displacement")
	var dimensional_lines := hero.get_tree().get_nodes_in_group("dimensional_cut_lines")
	_check(dimensional_lines.size() == 22, "ultimate should use the reduced set of 22 cut lines")
	var average_line_radius := 0.0
	for line in dimensional_lines:
		var cylinder := (line as MeshInstance3D).mesh as CylinderMesh
		_check(cylinder.top_radius <= 0.0241, "ultimate cut lines should keep the reduced maximum width")
		var offset := (line as MeshInstance3D).global_position - hero.global_position
		average_line_radius += Vector2(offset.x, offset.z).length()
	if not dimensional_lines.is_empty():
		average_line_radius /= dimensional_lines.size()
	_check(average_line_radius > 1.0, "ultimate cut centres should be biased away from the crowded centre")
	await _physics_frames(120)
	_check(is_equal_approx(hat_layer.position.x - hat_base_x, hero.sprite.position.x) and is_equal_approx(hat_layer.position.z - hat_base_z, hero.sprite.position.z), "ultimate hat and body should return to center together")
	_check(Vector2(hero.sprite.position.x, hero.sprite.position.z).length() < 0.05, "ultimate visual should settle back at the actor centre")
	hero.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	target.reset_runtime(Vector3(3.0, 0.05, 0.0))
	await _physics_frames(5)
	hero.energy = hero.definition.max_energy
	_check(hero.try_ability("ultimate"), "ultimate should start when no enemy is inside the circle")
	await _physics_frames(32)
	_check(hero.ability_phase != "active", "empty ultimate should skip the active animation entirely")
	_check(Vector2(hero.sprite.position.x, hero.sprite.position.z).length() < 0.05, "empty ultimate should not move the Cheems body")
	await _physics_frames(8)
	_check(not hero.status_controller.has_tag("untargetable"), "ultimate should not enter stage two when its startup circle is empty")
	_check(hero.get_parent().get_node_or_null("DimensionalMagicCircle") == null, "empty ultimate circle should disappear immediately after the 0.5 second startup")
	hero.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	target.reset_runtime(Vector3(-0.6, 0.05, 0.0))
	await _physics_frames(5)
	hero.energy = 0.0
	_check(hero.try_ability("basic", true), "sheathed basic should start")
	_check(hero.weapon_drawn and hero.basic_combo_step == 0, "first basic should draw the weapon and use combo step one")
	_check(is_equal_approx(hero.current_attack_damage_multiplier, 1.5), "draw slash should snapshot a 1.5 damage multiplier")
	await _physics_frames(30)
	_check(is_equal_approx(hero.energy, 5.0), "a successful basic should grant five sword-intent energy")
	_check(hero.try_ability("basic", true), "second chained basic should start before sheathing")
	_check(hero.basic_combo_step == 1 and is_equal_approx(hero.current_attack_damage_multiplier, 1.0), "second basic should be the upward slash at normal damage")
	await _physics_frames(52)
	_check(not hero.weapon_drawn, "weapon should return to the scabbard after half an attack interval without another basic")
	hero.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	target.reset_runtime(Vector3(-0.6, 0.05, 0.0))
	await _physics_frames(5)

	hero.hp = hero.definition.max_hp - 20.0
	hero.energy = 0.0
	_check(hero.try_ability("skill_w", true), "multi-slash should start")
	await _physics_frames(20)
	_check(hero.hp >= hero.definition.max_hp - 15.0, "each successful multi-slash pulse should heal five HP")
	_check(hero.energy >= 4.0, "each successful multi-slash pulse should grant sword-intent energy")
	hero.set_move_intent(Vector2.RIGHT)
	await _physics_frames(2)
	_check(hero.current_ability == null, "movement should cancel multi-slash")
	hero.set_move_intent(Vector2.ZERO)

	hero.facing = Vector3.RIGHT
	var hp_before := target.hp
	var energy_before := hero.energy
	_check(hero.try_ability("skill_e", true), "dash should start")
	await _physics_frames(16)
	_check(target.hp < hp_before, "dash path hitbox should damage the target")
	_check(hero.energy >= energy_before + 8.0, "a successful dash hit should grant eight sword-intent energy")
	_check(is_zero_approx(float(hero.cooldowns.get("skill_e", -1.0))), "dash hit should refresh its cooldown")

	var stun := CombatStatuses.stunned(1.0)
	hero.apply_status(stun, target.battle_id)
	_check(hero.status_controller.overhead_text() == "眩晕", "hard control should expose overhead text")
	hero.status_controller.clear()
	hero.apply_status(CombatStatuses.slow(1.0, 0.5), target.battle_id)
	_check(hero.status_controller.has_visual("slow"), "slow should expose a non-text visual tag")

	hero.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	hero.hp = 20.0
	_check(hero.receive_hit(target, target.definition.ability_by_id("basic"), Vector3.LEFT, 9000, 999.0), "overkill energy test hit should be accepted")
	_check(is_equal_approx(hero.energy, 7.6), "damage-taken sword intent should use actual health lost rather than overkill damage")
	hero.reset_runtime(Vector3(-2.0, 0.05, 0.0))
	var lethal_basic := target.definition.ability_by_id("basic")
	_check(hero.receive_hit(target, lethal_basic, Vector3.LEFT, 9001, hero.definition.max_hp + 1.0), "lethal damage should be accepted")
	await _physics_frames(35)
	_check(hero.sprite.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "body rotation should not be overwritten by automatic billboard rendering")
	_check(hero.is_defeated and is_equal_approx(absf(float(hero.sprite.get_meta("visual_angle", 0.0))), PI * 0.5), "death should finish in one of two visible 90-degree body falls")
	var death_hat := hero.visual_layer_sprites.get("hat") as Sprite3D
	var death_scabbard := hero.visual_layer_sprites.get("scabbard_back") as Sprite3D
	var death_blade := hero.visual_layer_sprites.get("katana_action") as Sprite3D
	var death_back_blade := hero.visual_layer_sprites.get("katana_back") as Sprite3D
	_check(death_hat.position.y <= 0.15 and death_scabbard.position.y <= 0.13, "hat and scabbard should fall to the ground")
	_check(death_blade.visible and not death_back_blade.visible, "death should plant the drawn blade and hide the back blade")

	hero.queue_free()
	target.queue_free()
	arena.queue_free()
	if failures.is_empty():
		print("Cheems samurai checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
