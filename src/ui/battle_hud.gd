class_name BattleHUD
extends CanvasLayer

signal return_to_menu_requested

const CooldownIconScript = preload("res://src/ui/ability_cooldown_icon.gd")
const StaminaRingScript = preload("res://src/ui/stamina_ring.gd")

var player: CombatActor
var bot: CombatActor
var player_hp: ProgressBar
var player_status: ProgressBar
var player_stamina: ProgressBar
var player_stamina_ring: StaminaRing
var bot_hp: ProgressBar
var bot_status: ProgressBar
var command_label: Label
var state_label: Label
var message_label: Label
var targeting_label: Label
var status_effect_label: Label
var ability_icons: Dictionary = {}
var respawn_mode_enabled := false


func setup(p_player: CombatActor, p_bot: CombatActor) -> void:
	player = p_player
	bot = p_bot
	_build_ui()


func set_respawn_mode(enabled: bool) -> void:
	respawn_mode_enabled = enabled


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	player_hp = _bar(root, Rect2(42.0, 24.0, 360.0, 22.0), player.definition.max_hp, player.relation_color(), Color("d8e5ec"), 2)
	player_status = _bar(root, Rect2(42.0, 50.0, 360.0, 10.0), player.definition.max_energy, player.definition.status_bar_color, Color("414d5a"), 1)
	player_status.visible = player.definition.max_energy > 0.0 and not player.definition.status_bar_id.is_empty()
	player_stamina = _bar(root, Rect2(42.0, 66.0, 270.0, 15.0), player.definition.max_stamina, Color("84dcf2"), Color("c9f3ff"), 2)
	player_stamina_ring = StaminaRingScript.new() as StaminaRing
	player_stamina_ring.position = Vector2(412.0, 14.0)
	player_stamina_ring.size = Vector2(58.0, 58.0)
	player_stamina_ring.setup(player)
	root.add_child(player_stamina_ring)
	bot_hp = _bar(root, Rect2(878.0, 24.0, 360.0, 22.0), bot.definition.max_hp, bot.relation_color(), Color("d8e5ec"), 2)
	bot_status = _bar(root, Rect2(878.0, 50.0, 360.0, 10.0), bot.definition.max_energy, bot.definition.status_bar_color, Color("414d5a"), 1)
	bot_status.visible = bot.definition.max_energy > 0.0 and not bot.definition.status_bar_id.is_empty()
	var player_name := _label(root, Rect2(42.0, 2.0, 360.0, 22.0), "PLAYER · %s" % player.actor_name, 16)
	player_name.add_theme_color_override("font_color", player.relation_color())
	var bot_name := _label(root, Rect2(878.0, 2.0, 360.0, 22.0), "%s · BOT" % bot.actor_name, 16)
	bot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bot_name.add_theme_color_override("font_color", bot.relation_color())
	var resource_text := "%s\nSTAMINA" % player.definition.status_bar_label if player_status.visible else "STAMINA"
	var resource_names := _label(root, Rect2(318.0, 47.0, 180.0, 38.0), resource_text, 11)
	resource_names.add_theme_color_override("font_color", Color("8da3b3"))
	var skill_row := HBoxContainer.new()
	skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_row.position = Vector2(475.0, 620.0)
	skill_row.add_theme_constant_override("separation", 10)
	root.add_child(skill_row)
	_add_skill_icon(skill_row, "skill_q", "Q")
	_add_skill_icon(skill_row, "skill_w", "W")
	_add_skill_icon(skill_row, "skill_e", "E")
	_add_skill_icon(skill_row, "ultimate", "R")
	command_label = _label(root, Rect2(32.0, 684.0, 740.0, 25.0), "", 13)
	state_label = _label(root, Rect2(880.0, 684.0, 360.0, 25.0), "", 13)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	targeting_label = _label(root, Rect2(420.0, 579.0, 440.0, 30.0), "右键移动 · 左键普攻", 17)
	targeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	targeting_label.add_theme_color_override("font_color", Color("c9dae5"))
	status_effect_label = _label(root, Rect2(42.0, 86.0, 430.0, 25.0), "", 13)
	status_effect_label.add_theme_color_override("font_color", Color("f3c879"))
	message_label = _label(root, Rect2(390.0, 82.0, 500.0, 52.0), "", 30)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color("ffe493"))
	var menu_button := Button.new()
	menu_button.text = "返回菜单"
	menu_button.position = Vector2(1140.0, 640.0)
	menu_button.size = Vector2(105.0, 36.0)
	menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_button.pressed.connect(return_to_menu_requested.emit)
	root.add_child(menu_button)


func _add_skill_icon(parent: HBoxContainer, ability_id: String, key_text: String) -> void:
	var icon := CooldownIconScript.new() as AbilityCooldownIcon
	icon.setup(player, ability_id, key_text)
	ability_icons[ability_id] = icon
	parent.add_child(icon)


func _bar(parent: Control, rect: Rect2, maximum: float, color: Color, border_color: Color, border_width: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.max_value = maximum
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("111821")
	background.border_color = border_color
	background.set_border_width_all(border_width)
	background.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _label(parent: Control, rect: Rect2, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	if player == null:
		return
	player_hp.value = player.hp
	player_status.value = player.energy
	player_stamina.value = player.stamina
	if bot != null and is_instance_valid(bot):
		bot_hp.value = bot.hp
		bot_status.value = bot.energy
	else:
		bot_hp.visible = false
		bot_status.visible = false
	command_label.text = "RMB 寻路 · LMB 攻击/确认 · QWER 技能 · SHIFT 翻滚 · SPACE 跳跃"
	if player.definition.max_energy > 0.0 and not player.definition.status_bar_id.is_empty():
		state_label.text = "体力 %.0f  ·  %s %.0f  ·  %s" % [player.stamina, player.definition.status_bar_label, player.energy, player.status_text()]
	else:
		state_label.text = "体力 %.0f  ·  %s" % [player.stamina, player.status_text()]
	status_effect_label.text = "  ·  ".join(player.status_controller.summaries())
	if respawn_mode_enabled:
		if player.is_defeated:
			message_label.text = "阵亡\n%.1f 秒后复活" % player.respawn_remaining
		elif message_label.text.begins_with("阵亡"):
			message_label.text = ""


func set_targeting(ability_id: String) -> void:
	for id in ability_icons.keys():
		(ability_icons[id] as AbilityCooldownIcon).set_selected(id == ability_id)
	if ability_id.is_empty():
		targeting_label.text = "右键移动 · 左键普攻"
	else:
		var ability := player.ability_by_id(ability_id)
		if ability == null:
			ability = player.definition.ability_by_id(ability_id)
		targeting_label.text = "正在瞄准 %s · 左键释放 · 右键取消并移动" % ability.display_name


func show_result(text: String) -> void:
	message_label.text = "%s\n按 F5 重新开始" % text


func clear_result() -> void:
	message_label.text = ""
