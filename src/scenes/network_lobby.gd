extends Control

var status_label: Label
var address_label: Label
var roster_box: VBoxContainer
var name_edit: LineEdit
var hero_select: OptionButton
var ready_button: Button
var start_button: Button
var feedback_label: Label
var leaving := false
var updating_name_edit := false


func _ready() -> void:
	_build_ui()
	NetworkSession.state_changed.connect(_on_state_changed)
	NetworkSession.lobby_changed.connect(_on_lobby_changed)
	NetworkSession.error_changed.connect(_on_error_changed)
	_refresh_all()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820.0, 610.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d2937")
	style.border_color = Color("4a647b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "局域网房间 · %s" % BrawlNetworkSession.GAME_VERSION
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color("8fd8ff"))
	column.add_child(status_label)
	address_label = Label.new()
	address_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	address_label.add_theme_color_override("font_color", Color("9db2c2"))
	column.add_child(address_label)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 10)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "玩家名"
	name_edit.max_length = 20
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_text_changed)
	name_edit.text_submitted.connect(_submit_profile_from_text)
	name_edit.focus_exited.connect(_submit_profile)
	profile_row.add_child(name_edit)
	hero_select = OptionButton.new()
	hero_select.custom_minimum_size.x = 220.0
	for hero_id in HeroCatalog.IDS:
		hero_select.add_item(HeroCatalog.display_name(hero_id))
		hero_select.set_item_metadata(hero_select.item_count - 1, hero_id)
	hero_select.item_selected.connect(_submit_profile_from_index)
	profile_row.add_child(hero_select)
	column.add_child(profile_row)
	var roster_title := Label.new()
	roster_title.text = "玩家列表"
	roster_title.add_theme_font_size_override("font_size", 20)
	column.add_child(roster_title)
	var roster_panel := PanelContainer.new()
	roster_panel.custom_minimum_size.y = 245.0
	var roster_style := StyleBoxFlat.new()
	roster_style.bg_color = Color("131d28")
	roster_style.set_corner_radius_all(8)
	roster_panel.add_theme_stylebox_override("panel", roster_style)
	column.add_child(roster_panel)
	var roster_margin := MarginContainer.new()
	roster_margin.add_theme_constant_override("margin_left", 18)
	roster_margin.add_theme_constant_override("margin_right", 18)
	roster_margin.add_theme_constant_override("margin_top", 14)
	roster_margin.add_theme_constant_override("margin_bottom", 14)
	roster_panel.add_child(roster_margin)
	roster_box = VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 8)
	roster_margin.add_child(roster_box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	ready_button = Button.new()
	ready_button.text = "准备"
	ready_button.toggle_mode = true
	ready_button.custom_minimum_size = Vector2(180.0, 46.0)
	ready_button.toggled.connect(NetworkSession.set_local_ready)
	actions.add_child(ready_button)
	start_button = Button.new()
	start_button.text = "房主开始"
	start_button.custom_minimum_size = Vector2(260.0, 46.0)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(NetworkSession.host_start_match)
	actions.add_child(start_button)
	var leave_button := Button.new()
	leave_button.text = "退出房间"
	leave_button.custom_minimum_size = Vector2(150.0, 46.0)
	leave_button.pressed.connect(_leave_room)
	actions.add_child(leave_button)
	column.add_child(actions)
	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color("ffb5a6"))
	feedback_label.custom_minimum_size.y = 28.0
	column.add_child(feedback_label)


func _refresh_all() -> void:
	_set_name_text(NetworkSession.local_display_name)
	_select_hero(NetworkSession.local_hero_id)
	_on_state_changed(NetworkSession.state)
	_on_lobby_changed(NetworkSession.roster())
	_on_error_changed(NetworkSession.last_error)
	var local := NetworkSession.local_player()
	if not local.is_empty():
		_set_name_text(str(local.get("display_name", "玩家")))
		_select_hero(str(local.get("hero_id", "cheems_samurai")))


func _on_state_changed(value: BrawlNetworkSession.State) -> void:
	match value:
		BrawlNetworkSession.State.CONNECTING: status_label.text = "正在查找 %s:%d 的房主（尚未加入房间）…" % [NetworkSession.host_address, BrawlNetworkSession.DEFAULT_PORT]
		BrawlNetworkSession.State.LOBBY: status_label.text = "已连接 · 等待所有玩家准备"
		BrawlNetworkSession.State.LOADING_MATCH: status_label.text = "正在同步加载测试地图…"
		_: status_label.text = "未连接"
	ready_button.disabled = value != BrawlNetworkSession.State.LOBBY
	start_button.disabled = not NetworkSession.can_host_start()
	start_button.visible = NetworkSession.is_host()
	if value == BrawlNetworkSession.State.OFFLINE and not leaving:
		get_tree().change_scene_to_file.bind("res://scenes/launcher.tscn").call_deferred()


func _on_lobby_changed(roster: Array) -> void:
	for child in roster_box.get_children():
		child.queue_free()
	for player_value in roster:
		var player := player_value as Dictionary
		var row := Label.new()
		var host_mark := " [房主]" if bool(player.get("is_host", false)) else ""
		var self_mark := " [自己]" if int(player.get("peer_id", 0)) == NetworkSession.local_peer_id() else ""
		var ready_text := "已准备" if bool(player.get("ready", false)) else "未准备"
		row.text = "#%d  %s%s%s    英雄：%s    %s" % [int(player.get("player_id", 0)), str(player.get("display_name", "玩家")), host_mark, self_mark, HeroCatalog.display_name(str(player.get("hero_id", ""))), ready_text]
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", Color("9fe3ad") if bool(player.get("ready", false)) else Color("d1dce4"))
		roster_box.add_child(row)
	var local := NetworkSession.local_player()
	if not local.is_empty():
		ready_button.set_pressed_no_signal(bool(local.get("ready", false)))
	start_button.disabled = not NetworkSession.can_host_start()
	address_label.text = "房间端口：UDP %d" % BrawlNetworkSession.DEFAULT_PORT
	if NetworkSession.is_host():
		address_label.text += "    建议加入地址：%s（不通时用 ipconfig 确认）" % NetworkSession.preferred_local_address()


func _on_error_changed(message: String) -> void:
	feedback_label.text = message


func _submit_profile() -> void:
	if hero_select.selected >= 0:
		NetworkSession.request_profile(name_edit.text, str(hero_select.get_item_metadata(hero_select.selected)))


func _submit_profile_from_text(_value: String) -> void:
	_submit_profile()


func _submit_profile_from_index(_index: int) -> void:
	if not NetworkSession.local_name_is_custom and hero_select.selected >= 0:
		_set_name_text(NetworkSession.suggested_display_name(str(hero_select.get_item_metadata(hero_select.selected))))
	_submit_profile()


func _on_name_text_changed(_value: String) -> void:
	if not updating_name_edit:
		NetworkSession.local_name_is_custom = true


func _set_name_text(value: String) -> void:
	updating_name_edit = true
	name_edit.text = value
	updating_name_edit = false


func _select_hero(hero_id: String) -> void:
	for index in range(hero_select.item_count):
		if str(hero_select.get_item_metadata(index)) == hero_id:
			hero_select.select(index)
			return


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		_leave_room()


func _leave_room() -> void:
	if leaving:
		return
	leaving = true
	NetworkSession.close_session()
	get_tree().change_scene_to_file.bind("res://scenes/launcher.tscn").call_deferred()
