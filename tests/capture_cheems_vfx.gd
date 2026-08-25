extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed: PackedScene = load("res://scenes/character_lab.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for _index in range(12):
		await process_frame
	var hero: CombatActor = scene.get("hero")
	var dummy: CombatActor = scene.get("dummy")
	dummy.global_position = hero.global_position + Vector3.RIGHT * 2.2
	hero.facing = Vector3.RIGHT
	await _capture_ability(hero, dummy, "basic", 10, "basic_right", 1.4, Vector3.RIGHT)
	await _capture_ability(hero, dummy, "basic", 10, "basic_left", 1.4, Vector3.LEFT)
	await _capture_ability(hero, dummy, "skill_q", 45, "q")
	await _capture_ability(hero, dummy, "skill_w", 35, "w")
	await _capture_ability(hero, dummy, "skill_e", 5, "e")
	dummy.global_position = hero.global_position + Vector3.RIGHT * 2.2
	await _capture_ability(hero, dummy, "ultimate", 18, "r_startup", 1.5)
	await _capture_ability(hero, dummy, "ultimate", 104, "r", 1.5)
	await _capture_death(hero, dummy, 1.0, "death_right")
	await _capture_death(hero, dummy, -1.0, "death_left")
	quit(0)


func _capture_ability(hero: CombatActor, dummy: CombatActor, ability_id: String, frames: int, suffix: String, dummy_distance := 2.2, facing_direction := Vector3.RIGHT) -> void:
	for projectile in get_nodes_in_group("combat_projectiles"):
		projectile.queue_free()
	for _index in range(2):
		await process_frame
	hero.reset_runtime(Vector3(-3.5, 0.05, 0.8))
	dummy.reset_runtime(Vector3(-3.5, 0.05, 0.8) + facing_direction * dummy_distance)
	hero.facing = facing_direction
	hero.energy = hero.definition.max_energy
	hero.ignore_ability_requirements = true
	hero.try_ability(ability_id, true)
	for _index in range(frames):
		await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://runtime/cheems_%s_preview.png" % suffix)
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [suffix, error_string(error)])


func _capture_death(hero: CombatActor, dummy: CombatActor, fall_side: float, suffix: String) -> void:
	for effect in get_nodes_in_group("transient_combat_vfx"):
		effect.queue_free()
	hero.reset_runtime(Vector3(-3.5, 0.05, 0.8))
	dummy.reset_runtime(Vector3(-1.8, 0.05, 0.8))
	hero.facing = Vector3.RIGHT
	for _index in range(2):
		await process_frame
	var basic := dummy.definition.ability_by_id("basic")
	hero.receive_hit(dummy, basic, Vector3.LEFT, 0, hero.definition.max_hp + 1.0)
	hero.death_fall_side = fall_side
	for _index in range(35):
		await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://runtime/cheems_%s_preview.png" % suffix)
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [suffix, error_string(error)])
