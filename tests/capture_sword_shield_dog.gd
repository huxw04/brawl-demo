extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed: PackedScene = load("res://scenes/character_lab.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	for _index in range(16):
		await process_frame
	scene.call("_spawn_lab_hero", "sword_shield_dog")
	for _index in range(12):
		await process_frame
	var hero: CombatActor = scene.get("hero")
	var dummy: CombatActor = scene.get("dummy")
	await _shot(hero, dummy, "idle", "", 1)
	await _shot(hero, dummy, "basic", "basic", 13)
	await _shot(hero, dummy, "guard", "skill_q", 25)
	await _shot(hero, dummy, "heavy_charge", "skill_w", 20)
	await _shot(hero, dummy, "heavy_chop", "skill_w", 34)
	await _shot(hero, dummy, "heavy_chop_aftershock", "skill_w", 128)
	await _shot(hero, dummy, "shield_bash", "skill_e", 24)
	await _shot(hero, dummy, "transform", "ultimate", 42)
	await _transformed_shot(hero, dummy, "swole_walk", "", 10)
	await _transformed_shot(hero, dummy, "swole_basic", "basic", 10)
	await _transformed_shot(hero, dummy, "swole_dash", "skill_w", 6)
	await _transformed_shot(hero, dummy, "swole_slam", "skill_e", 20)
	quit(0)


func _shot(hero: CombatActor, dummy: CombatActor, suffix: String, ability_id: String, frames: int) -> void:
	for effect in get_nodes_in_group("transient_combat_vfx"):
		effect.queue_free()
	for _index in range(2):
		await process_frame
	hero.reset_runtime(Vector3(-3.5, 0.05, 0.8))
	dummy.reset_runtime(Vector3(-1.5, 0.05, 0.8))
	hero.facing = Vector3.RIGHT
	hero.energy = hero.definition.max_energy
	if not ability_id.is_empty():
		hero.try_ability(ability_id, true)
	for _index in range(frames):
		await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://runtime/sword_shield_dog_%s_preview.png" % suffix)
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [suffix, error_string(error)])


func _transformed_shot(hero: CombatActor, dummy: CombatActor, suffix: String, ability_id: String, frames: int) -> void:
	for effect in get_nodes_in_group("transient_combat_vfx"):
		effect.queue_free()
	hero.reset_runtime(Vector3(-3.5, 0.05, 0.8))
	dummy.reset_runtime(Vector3(-1.5, 0.05, 0.8))
	hero.facing = Vector3.RIGHT
	hero.energy = hero.definition.max_energy
	hero.try_ability("ultimate", true)
	for _index in range(56):
		await process_frame
	if ability_id.is_empty():
		hero.set_move_intent(Vector2.RIGHT)
	else:
		hero.try_ability(ability_id, true)
	for _index in range(frames):
		await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://runtime/sword_shield_dog_%s_preview.png" % suffix)
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [suffix, error_string(error)])
	hero.set_move_intent(Vector2.ZERO)
