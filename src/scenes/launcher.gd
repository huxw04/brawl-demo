extends Control


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var card := PanelContainer.new()
	card.position = Vector2(340.0, 112.0)
	card.size = Vector2(600.0, 490.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d2937")
	style.border_color = Color("4a647b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_right", 52)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var title := Label.new()
	title.text = "BRAWL FRAMEWORK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("dff5ff"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Godot 3D 空间 · 2D 角色表现 · 首位角色：cheems"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("8faabd"))
	column.add_child(subtitle)
	column.add_spacer(false)
	column.add_child(_scene_button("角色实验室", "判定框、动作、技能和资源调试", "res://scenes/character_lab.tscn"))
	column.add_child(_scene_button("战斗测试", "右键寻路、左键攻击，对战规则型 Bot", "res://scenes/battle_arena.tscn"))
	var note := Label.new()
	note.text = "实验室与实战共用 CombatActor 和技能执行器\nF1 随时返回 · F3 显示/隐藏判定框"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("7f95a6"))
	column.add_child(note)


func _scene_button(title: String, description: String, path: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(480.0, 84.0)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(func() -> void: get_tree().change_scene_to_file(path))
	return button
