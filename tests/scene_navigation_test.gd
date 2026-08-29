extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/battle_arena.tscn")
	await _frames(5)
	var battle := current_scene
	_check(battle != null and battle.scene_file_path == "res://scenes/battle_arena.tscn", "battle scene should load before testing F1")
	if battle != null:
		battle.start_battle("cheems_samurai")
		await _frames(3)
		_send_f1()
		await _frames(5)
		_check(current_scene != null and current_scene.scene_file_path == "res://scenes/launcher.tscn", "F1 should safely return from battle to the launcher")
		var launcher := current_scene
		_check(launcher.hero_select != null, "launcher should expose hero selection beside the player name")
		if launcher.hero_select != null:
			var nailoong_index := HeroCatalog.IDS.find("nailoong")
			launcher.hero_select.select(nailoong_index)
			launcher._on_hero_selected(nailoong_index)
			_check(launcher.name_edit.text.begins_with("奶龙_"), "an untouched automatic name should follow launcher hero selection")
			launcher.name_edit.text = "自定义玩家"
			launcher._on_name_changed("自定义玩家")
			var cheems_index := HeroCatalog.IDS.find("cheems_samurai")
			launcher.hero_select.select(cheems_index)
			launcher._on_hero_selected(cheems_index)
			_check(launcher.name_edit.text == "自定义玩家", "a manually edited launcher name should remain stable across hero changes")

	change_scene_to_file("res://scenes/character_lab.tscn")
	await _frames(5)
	var lab := current_scene
	_check(lab != null and lab.scene_file_path == "res://scenes/character_lab.tscn", "Lab scene should load before testing F1")
	if lab != null:
		_send_f1()
		await _frames(5)
		_check(current_scene != null and current_scene.scene_file_path == "res://scenes/launcher.tscn", "F1 should safely return from Lab to the launcher")

	if failures.is_empty():
		print("Scene navigation checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _send_f1() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F1
	event.physical_keycode = KEY_F1
	event.pressed = true
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
