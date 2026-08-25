extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed_scene: PackedScene = load("res://scenes/character_lab.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	for _index in range(8):
		await process_frame
	scene.call("_spawn_lab_hero", "chu_ying")
	for _index in range(10):
		await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://runtime/chu_ying_preview.png")
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save Chu Ying preview: %s" % error_string(error))
		quit(1)
	else:
		print("Saved preview: %s" % output)
		quit(0)
