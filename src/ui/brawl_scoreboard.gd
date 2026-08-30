class_name BrawlScoreboard
extends CanvasLayer

const QualityIconScript = preload("res://src/ui/network_quality_icon.gd")
const KillIconScript = preload("res://src/ui/kill_feed_icon.gd")

var local_actor_id := 0
var expanded := false
var current_state: Dictionary = {}
var participants_by_actor: Dictionary = {}
var latency_by_actor: Dictionary = {}
var remaining_time := 0.0
var timer_running := false
var timer_label: Label
var board_panel: PanelContainer
var board_header: Label
var board_rows: VBoxContainer
var board_signature := ""
var announcement_panel: PanelContainer
var announcement_killer_name: Label
var announcement_killer_portrait: TextureRect
var announcement_phrase: Label
var announcement_victim_name: Label
var announcement_victim_portrait: TextureRect
var announcement_tween: Tween
var result_panel: PanelContainer
var result_title: Label
var result_table: Label


func setup(p_local_actor_id: int, participants: Array = []) -> void:
	local_actor_id = p_local_actor_id
	for value in participants:
		var participant := value as Dictionary
		participants_by_actor[int(participant.get("actor_id", 0))] = participant.duplicate(true)
	layer = 24
	_build_ui()
	_refresh_board(true)


func apply_match_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var preserved_quality = current_state.get("network_quality", [])
	current_state = state.duplicate(true)
	if not current_state.has("network_quality") and preserved_quality is Array:
		current_state["network_quality"] = (preserved_quality as Array).duplicate(true)
	_apply_network_quality(current_state.get("network_quality", []) as Array)
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
	var killer_id := int(payload.get("killer_actor_id", 0))
	var victim_id := int(payload.get("victim_actor_id", 0))
	announcement_killer_name.text = _actor_name(killer_id)
	announcement_victim_name.text = _actor_name(victim_id)
	announcement_killer_portrait.texture = _portrait_texture(killer_id)
	announcement_victim_portrait.texture = _portrait_texture(victim_id)
	announcement_phrase.text = "终结" if bool(payload.get("shutdown", false)) else _streak_title(int(payload.get("killer_streak", 0)), str(payload.get("phrase", "")))
	announcement_phrase.add_theme_color_override("font_color", Color("ffd267") if bool(payload.get("shutdown", false)) else Color("f2f5ff"))
	announcement_panel.visible = true
	announcement_panel.modulate = Color.WHITE
	if announcement_tween != null and announcement_tween.is_valid():
		announcement_tween.kill()
	announcement_tween = create_tween()
	announcement_tween.tween_interval(2.1)
	announcement_tween.tween_property(announcement_panel, "modulate:a", 0.0, 0.65)
	announcement_tween.tween_callback(func() -> void: announcement_panel.visible = false)


func show_results(payload: Dictionary) -> void:
	var state := payload.get("state", current_state) as Dictionary
	if not state.is_empty():
		var preserved_quality = current_state.get("network_quality", [])
		current_state = state.duplicate(true)
		if not current_state.has("network_quality") and preserved_quality is Array:
			current_state["network_quality"] = (preserved_quality as Array).duplicate(true)
		_apply_network_quality(current_state.get("network_quality", []) as Array)
		remaining_time = float(state.get("remaining_time", remaining_time))
	var winner_id := int(current_state.get("winner_actor_id", payload.get("winner_actor_id", 0)))
	var winner_name := _actor_name(winner_id)
	result_title.text = "比赛结束 · 平局" if winner_id <= 0 else "比赛结束 · %s 获胜" % winner_name
	result_table.text = _result_table_text()
	result_panel.visible = true
	expanded = false
	_refresh_board(true)


func _process(delta: float) -> void:
	if timer_running:
		remaining_time = maxf(0.0, remaining_time - delta)
		_refresh_timer()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.keycode != KEY_TAB or event.echo:
		return
	expanded = event.pressed
	_refresh_board(true)
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	timer_label = Label.new()
	timer_label.position = Vector2(565.0, 6.0)
	timer_label.size = Vector2(150.0, 40.0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 25)
	timer_label.add_theme_constant_override("outline_size", 5)
	timer_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	add_child(timer_label)

	board_panel = PanelContainer.new()
	board_panel.position = Vector2(18.0, 132.0)
	board_panel.custom_minimum_size = Vector2(390.0, 0.0)
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.06, 0.78), Color(0.33, 0.5, 0.62, 0.65)))
	add_child(board_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	board_panel.add_child(margin)
	var board_column := VBoxContainer.new()
	board_column.add_theme_constant_override("separation", 5)
	margin.add_child(board_column)
	board_header = Label.new()
	board_header.add_theme_font_size_override("font_size", 14)
	board_header.add_theme_color_override("font_color", Color("91a9b8"))
	board_column.add_child(board_header)
	board_rows = VBoxContainer.new()
	board_rows.add_theme_constant_override("separation", 3)
	board_column.add_child(board_rows)

	_build_announcement()
	_build_results()


func _build_announcement() -> void:
	announcement_panel = PanelContainer.new()
	announcement_panel.position = Vector2(340.0, 44.0)
	announcement_panel.size = Vector2(600.0, 88.0)
	announcement_panel.visible = false
	announcement_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announcement_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.026, 0.04, 0.86), Color(0.64, 0.72, 0.78, 0.42)))
	add_child(announcement_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	announcement_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var killer_card := _portrait_card()
	announcement_killer_name = killer_card.get("name_label") as Label
	announcement_killer_portrait = killer_card.get("portrait") as TextureRect
	row.add_child(killer_card.get("root") as Control)
	announcement_phrase = Label.new()
	announcement_phrase.custom_minimum_size = Vector2(190.0, 64.0)
	announcement_phrase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement_phrase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	announcement_phrase.add_theme_font_size_override("font_size", 21)
	announcement_phrase.add_theme_constant_override("outline_size", 5)
	announcement_phrase.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	row.add_child(announcement_phrase)
	row.add_child(_build_kill_icon())
	var victim_card := _portrait_card()
	announcement_victim_name = victim_card.get("name_label") as Label
	announcement_victim_portrait = victim_card.get("portrait") as TextureRect
	row.add_child(victim_card.get("root") as Control)


func _portrait_card() -> Dictionary:
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(82.0, 78.0)
	root.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(82.0, 18.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("e4edf4"))
	root.add_child(name_label)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(56.0, 56.0)
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.1, 0.13, 0.92), Color("a9bbc7")))
	root.add_child(frame)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(56.0, 56.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	return {"root": root, "name_label": name_label, "portrait": portrait}


func _build_kill_icon() -> Control:
	return KillIconScript.new() as KillFeedIcon


func _build_results() -> void:
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


func _refresh_board(force := false) -> void:
	if board_rows == null:
		return
	var signature := "%s|%s|%s" % [expanded, JSON.stringify(current_state.get("stats", [])), JSON.stringify(latency_by_actor)]
	if not force and signature == board_signature:
		return
	board_signature = signature
	for child in board_rows.get_children():
		child.queue_free()
	board_header.text = "网络　玩家　　　　　　 K / D / A　[松开 Tab 收起]" if expanded else "比分　[按住 Tab 展开]"
	if expanded:
		for value in current_state.get("stats", []):
			_add_score_row(value as Dictionary)
	else:
		var local_row := _stat(local_actor_id)
		if local_row.is_empty():
			var waiting := Label.new()
			waiting.text = "等待比赛数据…"
			waiting.add_theme_color_override("font_color", Color("a8bbc7"))
			board_rows.add_child(waiting)
		else:
			_add_score_row(local_row)


func _add_score_row(row: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.custom_minimum_size.y = 23.0
	line.add_theme_constant_override("separation", 5)
	board_rows.add_child(line)
	var quality := QualityIconScript.new() as NetworkQualityIcon
	quality.set_latency(int(latency_by_actor.get(int(row.get("actor_id", 0)), -1)))
	line.add_child(quality)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(205.0, 22.0)
	name_label.text = "%s %s" % ["▶" if int(row.get("actor_id", 0)) == local_actor_id else " ", str(row.get("name", "玩家")).left(14)]
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", Color("d9e7f0"))
	line.add_child(name_label)
	var kda := Label.new()
	kda.custom_minimum_size = Vector2(110.0, 22.0)
	kda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kda.text = "%2d / %2d / %2d" % [int(row.get("kills", 0)), int(row.get("deaths", 0)), int(row.get("assists", 0))]
	kda.add_theme_color_override("font_color", Color("f0f4f7"))
	line.add_child(kda)


func _apply_network_quality(rows: Array) -> void:
	for value in rows:
		var row := value as Dictionary
		var latency := int(row.get("latency_ms", -1))
		latency_by_actor[int(row.get("actor_id", 0))] = roundi(float(latency) / 25.0) * 25 if latency >= 0 else -1


func _result_table_text() -> String:
	var lines: Array[String] = ["玩家　　　　　　 K / D / A　　输出　　承伤　　治疗"]
	for value in current_state.get("stats", []):
		var row := value as Dictionary
		var marker := "▶" if int(row.get("actor_id", 0)) == local_actor_id else " "
		lines.append("%s %-14s  %2d / %2d / %2d　%5d　%5d　%5d" % [
			marker, str(row.get("name", "玩家")).left(14), int(row.get("kills", 0)), int(row.get("deaths", 0)), int(row.get("assists", 0)),
			roundi(float(row.get("damage_dealt", 0.0))), roundi(float(row.get("damage_taken", 0.0))), roundi(float(row.get("healing", 0.0))),
		])
	return "\n".join(lines)


func _streak_title(streak: int, phrase: String) -> String:
	var prefix := ""
	match streak:
		1: prefix = "一破"
		2: prefix = "双连"
		3: prefix = "三连"
		4: prefix = "四连"
		5: prefix = "五连"
		6: prefix = "六连"
		_: prefix = "七连" if streak >= 7 else ""
	return "%s·%s" % [prefix, phrase] if not prefix.is_empty() and not phrase.is_empty() else phrase


func _portrait_texture(actor_id: int) -> Texture2D:
	var participant := participants_by_actor.get(actor_id, {}) as Dictionary
	var hero_id := str(participant.get("hero_id", "placeholder_vanguard"))
	var source := HeroCatalog.create(hero_id).sprite_texture
	if source == null:
		return null
	var normalized_region := Rect2(0.12, 0.0, 0.76, 0.62)
	if hero_id in ["bear_grylls_jungler", "chu_ying"]:
		normalized_region = Rect2(0.16, 0.0, 0.68, 0.48)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(
		normalized_region.position.x * source.get_width(),
		normalized_region.position.y * source.get_height(),
		normalized_region.size.x * source.get_width(),
		normalized_region.size.y * source.get_height()
	)
	return atlas


func _actor_name(actor_id: int) -> String:
	var row := _stat(actor_id)
	if not row.is_empty():
		return str(row.get("name", "玩家"))
	return str((participants_by_actor.get(actor_id, {}) as Dictionary).get("display_name", "环境" if actor_id <= 0 else "玩家"))


func _stat(actor_id: int) -> Dictionary:
	for value in current_state.get("stats", []):
		var row := value as Dictionary
		if int(row.get("actor_id", 0)) == actor_id:
			return row
	return {}


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
