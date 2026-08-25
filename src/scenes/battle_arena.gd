extends Node3D

const ActorScript = preload("res://src/combat/combat_actor.gd")
const BotScript = preload("res://src/ai/utility_bot.gd")
const HUDScript = preload("res://src/ui/battle_hud.gd")
const ArenaScript = preload("res://src/presentation/arena_world.gd")

var arena: ArenaWorld
var player: CombatActor
var bot: CombatActor
var bot_controller: UtilityBot
var player_controller: MobaPlayerController
var command_stream: BattleCommandStream
var command_motors: Dictionary = {}
var battle_rng := BattleRng.new(20260822)
var hud: BattleHUD
var pathfinder: ArenaPathfinder
var selection_layer: CanvasLayer
var battle_over := true


func _ready() -> void:
	arena = ArenaScript.new() as ArenaWorld
	arena.title = "BATTLE TEST"
	arena.include_test_walls = true
	add_child(arena)
	command_stream = BattleCommandStream.new()
	command_stream.name = "BattleCommandStream"
	add_child(command_stream)
	pathfinder = ArenaPathfinder.new()
	pathfinder.configure(arena.navigation_obstacles)
	_build_hero_selection()


func _build_hero_selection() -> void:
	selection_layer = CanvasLayer.new()
	selection_layer.name = "HeroSelection"
	selection_layer.layer = 30
	add_child(selection_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.035, 0.05, 0.78)
	selection_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430.0, 250.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.10, 0.14, 0.98)
	panel_style.border_color = Color("57738b")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = "选择测试英雄"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var help := Label.new()
	help.text = "进入战斗后对阵规则型 Bot；F5 重置，F1 返回菜单"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("a9bfce"))
	column.add_child(help)
	var hero_select := OptionButton.new()
	for id in HeroCatalog.IDS:
		hero_select.add_item(HeroCatalog.display_name(id))
		hero_select.set_item_metadata(hero_select.item_count - 1, id)
	hero_select.select(1)
	column.add_child(hero_select)
	var start_button := Button.new()
	start_button.text = "开始战斗"
	start_button.custom_minimum_size.y = 48.0
	start_button.pressed.connect(func() -> void: start_battle(str(hero_select.get_item_metadata(hero_select.selected))))
	column.add_child(start_button)


func start_battle(hero_id: String = "cheems_samurai") -> void:
	if player != null:
		return
	if selection_layer != null:
		selection_layer.queue_free()
		selection_layer = null
	player = ActorScript.new() as CombatActor
	add_child(player)
	var player_definition := HeroCatalog.create(hero_id)
	player.setup(player_definition, 1, player_definition.display_name, CombatActor.Relation.SELF)
	player.battle_id = 1
	bot = ActorScript.new() as CombatActor
	add_child(bot)
	bot.setup(PlaceholderHero.create(), 2, "BOT", CombatActor.Relation.ENEMY)
	bot.battle_id = 2
	_add_motor(player, pathfinder)
	_add_motor(bot, pathfinder)
	player_controller = MobaPlayerController.new()
	add_child(player_controller)
	player_controller.setup(player, arena, command_stream)
	bot_controller = BotScript.new() as UtilityBot
	add_child(bot_controller)
	bot_controller.setup(bot, player, command_stream, battle_rng)
	hud = HUDScript.new() as BattleHUD
	add_child(hud)
	hud.setup(player, bot)
	player_controller.targeting_changed.connect(hud.set_targeting)
	player.defeated.connect(func(_actor: CombatActor) -> void: _end_battle("BOT 获胜"))
	bot.defeated.connect(func(_actor: CombatActor) -> void: _end_battle("PLAYER 获胜"))
	_reset_battle()


func _add_motor(actor: CombatActor, pathfinder: ArenaPathfinder) -> void:
	var motor := CommandMotor.new()
	add_child(motor)
	motor.setup(actor, pathfinder)
	command_motors[actor.battle_id] = motor


func _physics_process(_delta: float) -> void:
	if battle_over or command_stream == null or player == null:
		return
	for command in command_stream.advance_tick():
		var motor = command_motors.get(command.actor_id)
		if motor is CommandMotor:
			motor.apply_command(command)
	for motor in command_motors.values():
		(motor as CommandMotor).advance_movement()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			get_tree().change_scene_to_file("res://scenes/launcher.tscn")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			CombatActor.debug_shapes = not CombatActor.debug_shapes
			get_tree().call_group("debug_visuals", "refresh_debug_visibility")
		elif event.keycode == KEY_F5:
			if player != null:
				_reset_battle()


func _end_battle(text: String) -> void:
	battle_over = true
	for motor in command_motors.values():
		(motor as CommandMotor).stop()
	hud.show_result(text)


func _reset_battle() -> void:
	if player == null or bot == null:
		return
	for child in get_children():
		if child is CombatProjectile or child is DelayedGroundAttack or child.is_in_group("transient_combat_vfx"):
			child.queue_free()
	command_stream.reset()
	battle_rng.reset(20260822)
	for motor in command_motors.values():
		(motor as CommandMotor).stop()
	player.reset_runtime(Vector3(-4.6, 0.05, 1.4))
	bot.reset_runtime(Vector3(4.6, 0.05, 1.4))
	player.facing = Vector3.RIGHT
	bot.facing = Vector3.LEFT
	battle_over = false
	if hud != null:
		hud.clear_result()


func current_state_checksum() -> String:
	if player == null or bot == null:
		return "not_started"
	return BattleStateDigest.checksum(command_stream.current_tick, [player, bot], battle_rng)
