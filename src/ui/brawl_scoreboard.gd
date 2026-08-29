class_name BrawlScoreboard
extends CanvasLayer

var local_actor_id := 0
var expanded := false
var current_state: Dictionary = {}
var remaining_time := 0.0
var timer_running := false
var timer_label: Label
var board_panel: PanelContainer
var board_label: Label
var announcement_label: Label
var announcement_tween: Tween
var result_panel: PanelContainer
var result_title: Label
var result_table: Label


func setup(p_local_actor_id: int) -> void:
	local_actor_id = p_local_actor_id
	layer = 24
	_build_ui()


func apply_match_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	current_state = state.duplicate(true)
	remaining_time = maxf(0.0, float(state.get("remaining_time", remaining_time)))
	timer_running = bool(state.get("running", false)) and not bool(state.get("ended", false))
	_refresh_timer()
	_refresh_board()
	if bool(state.get("ended", false)):
		show_results({"state": state})


func show_kill_announcement(payload: Dictionary) -> void:
	var state := payload.get("state", {}) as Dictionary
	if not state.is_empty():
		apply_match_state(state)
	announcement_label.text = str(payload.get("announcement", ""))
	announcement_label.modulate = Color.WHITE
	announcement_label.add_theme_color_override(
		"font_color",
		Color("ffd267") if bool(payload.get("shutdown", false)) else Color("f2f5ff")
	)
	if announcement_tween != null and announcement_tween.is_valid():
		announcement_tween.kill()
	announcement_tween = create_tween()
	announcement_tween.tween_interval(2.1)
	announcement_tween.tween_property(announcement_label, "modulate:a", 0.0, 0.65)


func show_results(payload: Dictionary) -> void:
	var state := payload.get("state", current_state) as Dictionary
	if not state.is_empty():
		current_state = state.duplicate(true)
		remaining_time = float(state.get("remaining_time", remaining_time))
	var winner_id := int(current_state.get("winner_actor_id", payload.get("winner_actor_id", 0)))
	var winner_name := _actor_name(winner_id)
	result_title.text = "比赛结束 · 平局" if winner_id <= 0 else "比赛结束 · %s 获胜" % winner_name
	result_table.text = _table_text(true)
	result_panel.visible = true
	expanded = false
	_refresh_board()


func _process(delta: float) -> void:
	if timer_running:
		remaining_time = maxf(0.0, remaining_time - delta)
		_refresh_timer()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.keycode != KEY_TAB or not event.pressed or event.echo:
		return
	expanded = not expanded
	_refresh_board()
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	timer_label = Label.new()
	timer_label.position = Vector2(565.0, 156.0)
	timer_label.size = Vector2(150.0, 40.0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 25)
	timer_label.add_theme_constant_override("outline_size", 5)
	timer_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	add_child(timer_label)

	board_panel = PanelContainer.new()
	board_panel.position = Vector2(18.0, 132.0)
	board_panel.custom_minimum_size = Vector2(350.0, 0.0)
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.06, 0.78), Color(0.33, 0.5, 0.62, 0.65)))
	add_child(board_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	board_panel.add_child(margin)
	board_label = Label.new()
	board_label.add_theme_font_size_override("font_size", 15)
	board_label.add_theme_color_override("font_color", Color("d9e7f0"))
	margin.add_child(board_label)

	announcement_label = Label.new()
	announcement_label.position = Vector2(290.0, 205.0)
	announcement_label.size = Vector2(700.0, 48.0)
	announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_label.add_theme_font_size_override("font_size", 30)
	announcement_label.add_theme_constant_override("outline_size", 7)
	announcement_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	announcement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(announcement_label)

	result_panel = PanelContainer.new()
	result_panel.position = Vector2(310.0, 205.0)
	result_panel.size = Vector2(660.0, 325.0)
	result_panel.visible = false
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.065, 0.95), Color("7aaac4")))
	add_child(result_panel)
	var result_margin := MarginContainer.new()
	result_margin.add_theme_constant_override("margin_left", 24)
	result_margin.add_theme_constant_override("margin_right", 24)
	result_margin.add_theme_constant_override("margin_top", 20)
	result_margin.add_theme_constant_override("margin_bottom", 20)
	result_panel.add_child(result_margin)
	var result_column := VBoxContainer.new()
	result_column.add_theme_constant_override("separation", 16)
	result_margin.add_child(result_column)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 28)
	result_title.add_theme_color_override("font_color", Color("ffe093"))
	result_column.add_child(result_title)
	result_table = Label.new()
	result_table.add_theme_font_size_override("font_size", 17)
	result_table.add_theme_color_override("font_color", Color("e0ebf2"))
	result_column.add_child(result_table)
	var hint := Label.new()
	hint.text = "F1 或右下角按钮返回菜单"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("8fa6b6"))
	result_column.add_child(hint)


func _refresh_timer() -> void:
	var total_seconds := maxi(0, int(ceil(remaining_time)))
	timer_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _refresh_board() -> void:
	if board_label == null:
		return
	board_label.text = ("比分榜　K / D / A　[Tab 收起]\n" + _table_text(false)) if expanded else "比分　[Tab 展开]\n%s" % _local_row()


func _local_row() -> String:
	for value in current_state.get("stats", []):
		var row := value as Dictionary
		if int(row.get("actor_id", 0)) == local_actor_id:
			return _format_row(row, false)
	return "等待比赛数据…"


func _table_text(include_damage: bool) -> String:
	var lines: Array[String] = []
	if include_damage:
		lines.append("玩家　　　　　　 K / D / A　　输出　　承伤")
	for value in current_state.get("stats", []):
		lines.append(_format_row(value as Dictionary, include_damage))
	return "\n".join(lines)


func _format_row(row: Dictionary, include_damage: bool) -> String:
	var marker := "▶" if int(row.get("actor_id", 0)) == local_actor_id else " "
	var base := "%s %-14s  %2d / %2d / %2d" % [
		marker,
		str(row.get("name", "玩家")).left(14),
		int(row.get("kills", 0)),
		int(row.get("deaths", 0)),
		int(row.get("assists", 0)),
	]
	if include_damage:
		base += "　%5d　%5d" % [roundi(float(row.get("damage_dealt", 0.0))), roundi(float(row.get("damage_taken", 0.0)))]
	return base


func _actor_name(actor_id: int) -> String:
	for value in current_state.get("stats", []):
		var row := value as Dictionary
		if int(row.get("actor_id", 0)) == actor_id:
			return str(row.get("name", "玩家"))
	return "玩家"


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
