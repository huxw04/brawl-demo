extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed_scene: PackedScene = load("res://scenes/character_lab.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	for _index in range(12):
		await process_frame
	var hero: CombatActor = scene.get("hero")
	hero.try_ability("basic", true)
	for _index in range(8):
		await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://runtime/lab_preview.png")
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save preview: %s" % error_string(error))
		quit(1)
	else:
		print("Saved preview: %s" % output)
	scene.queue_free()
	for _index in range(3):
		await process_frame
	var battle_packed: PackedScene = load("res://scenes/battle_arena.tscn")
	var battle: Node = battle_packed.instantiate()
	root.add_child(battle)
	battle.call("start_battle", "cheems_samurai")
	for _index in range(12):
		await process_frame
	battle.get("bot_controller").process_mode = Node.PROCESS_MODE_DISABLED
	var player: CombatActor = battle.get("player")
	player.stamina = 42.0
	player.cooldowns["skill_q"] = player.definition.ability_by_id("skill_q").cooldown
	player.cooldowns["skill_w"] = player.definition.ability_by_id("skill_w").cooldown * 0.58
	player.cooldowns["skill_e"] = player.definition.ability_by_id("skill_e").cooldown * 0.24
	battle.get("hud").set_targeting("skill_w")
	for _index in range(3):
		await process_frame
	image = root.get_texture().get_image()
	output = ProjectSettings.globalize_path("res://runtime/battle_preview.png")
	error = image.save_png(output)
	if error != OK:
		push_error("Could not save battle preview: %s" % error_string(error))
		quit(1)
	else:
		print("Saved preview: %s" % output)
		quit(0)
