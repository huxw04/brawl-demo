extends Control

var name_edit: LineEdit
var address_edit: LineEdit
var hero_select: OptionButton
var feedback_label: Label
var name_user_edited := false
var updating_name_edit := false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var card := PanelContainer.new()
	card.position = Vector2(275.0, 28.0)
	card.size = Vector2(730.0, 664.0)
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
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "BRAWL FRAMEWORK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("dff5ff"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "3D 战斗空间 · 2D 角色表现 · %s" % BrawlNetworkSession.GAME_VERSION
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("8faabd"))
	column.add_child(subtitle)
	column.add_child(_scene_button("角色实验室", "判定框、动作、技能和资源调试", "res://scenes/character_lab.tscn"))
	column.add_child(_scene_button("战斗测试", "右键寻路、左键攻击，对战规则型 Bot", "res://scenes/battle_arena.tscn"))
	column.add_child(HSeparator.new())
	var network_title := Label.new()
	network_title.text = "局域网房间"
	network_title.add_theme_font_size_override("font_size", 21)
	network_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(network_title)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 10)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "玩家名"
	name_edit.max_length = 20
	name_edit.custom_minimum_size.y = 38.0
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_name_text(NetworkSession.local_display_name if NetworkSession.local_name_is_custom else NetworkSession.suggested_display_name(NetworkSession.local_hero_id))
	_refresh_name_color()
	name_edit.text_changed.connect(_on_name_changed)
	profile_row.add_child(name_edit)
	hero_select = OptionButton.new()
	hero_select.custom_minimum_size = Vector2(220.0, 38.0)
	for hero_id in HeroCatalog.IDS:
		hero_select.add_item(HeroCatalog.display_name(hero_id))
		hero_select.set_item_metadata(hero_select.item_count - 1, hero_id)
		if hero_id == NetworkSession.local_hero_id:
			hero_select.select(hero_select.item_count - 1)
	hero_select.item_selected.connect(_on_hero_selected)
	profile_row.add_child(hero_select)
	column.add_child(profile_row)
	var address_row := HBoxContainer.new()
	address_row.add_theme_constant_override("separation", 10)
	address_edit = LineEdit.new()
	address_edit.placeholder_text = "房主 IPv4 地址"
	address_edit.text = "127.0.0.1"
	address_edit.custom_minimum_size = Vector2(360.0, 40.0)
	address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_row.add_child(address_edit)
	var join_button := Button.new()
	join_button.text = "根据 IP 加入"
	join_button.custom_minimum_size = Vector2(170.0, 40.0)
	join_button.pressed.connect(_join_room)
	address_row.add_child(join_button)
	column.add_child(address_row)
	var host_button := Button.new()
	host_button.text = "创建局域网房间（UDP %d）" % BrawlNetworkSession.DEFAULT_PORT
	host_button.custom_minimum_size.y = 42.0
	host_button.pressed.connect(_host_room)
	column.add_child(host_button)
	feedback_label = Label.new()
	feedback_label.text = NetworkSession.last_error
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("ffb5a6"))
	feedback_label.custom_minimum_size.y = 40.0
	column.add_child(feedback_label)
	var note := Label.new()
	note.text = "本机双窗口测试：一个窗口创建，另一个输入 127.0.0.1 加入\nF1 返回 · F3 显示/隐藏判定框"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color("7f95a6"))
	column.add_child(note)


func _scene_button(title: String, description: String, path: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, description]
	button.custom_minimum_size = Vector2(560.0, 62.0)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(_open_scene.bind(path))
	return button


func _open_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _host_room() -> void:
	NetworkSession.local_name_is_custom = name_user_edited or NetworkSession.local_name_is_custom
	var result := NetworkSession.host_room(name_edit.text, _selected_hero_id())
	if result == OK:
		get_tree().change_scene_to_file("res://scenes/network_lobby.tscn")
	else:
		feedback_label.text = NetworkSession.last_error


func _join_room() -> void:
	NetworkSession.local_name_is_custom = name_user_edited or NetworkSession.local_name_is_custom
	var result := NetworkSession.join_room(address_edit.text, name_edit.text, _selected_hero_id())
	if result == OK:
		get_tree().change_scene_to_file("res://scenes/network_lobby.tscn")
	else:
		feedback_label.text = NetworkSession.last_error


func _on_name_changed(_value: String) -> void:
	if updating_name_edit:
		return
	name_user_edited = true
	NetworkSession.local_name_is_custom = true
	_refresh_name_color()


func _on_hero_selected(_index: int) -> void:
	if not name_user_edited and not NetworkSession.local_name_is_custom:
		_set_name_text(NetworkSession.suggested_display_name(_selected_hero_id()))
		_refresh_name_color()


func _selected_hero_id() -> String:
	if hero_select == null or hero_select.selected < 0:
		return "cheems_samurai"
	return str(hero_select.get_item_metadata(hero_select.selected))


func _set_name_text(value: String) -> void:
	updating_name_edit = true
	name_edit.text = value
	updating_name_edit = false


func _refresh_name_color() -> void:
	if name_edit != null:
		name_edit.add_theme_color_override("font_color", Color.WHITE if name_user_edited or NetworkSession.local_name_is_custom else Color("aeb8c0"))
