extends Node3D

const ActorScript = preload("res://src/combat/combat_actor.gd")
const ArenaScript = preload("res://src/presentation/arena_world.gd")
const CommandRuntimeScript = preload("res://src/commands/battle_command_runtime.gd")
const MoveIndicatorScript = preload("res://src/presentation/move_destination_indicator.gd")
const TargetingPreviewScript = preload("res://src/presentation/ability_targeting_preview.gd")
const MatchAuthorityScript = preload("res://src/core/match_authority.gd")
const AuthorityEventPresentationScript = preload("res://src/presentation/authority_event_presentation.gd")

var hero: CombatActor
var dummy: CombatActor
var status_label: Label
var event_label: Label
var bypass_check: CheckButton
var event_lines: Array[String] = []
var arena: ArenaWorld
var command_stream: BattleCommandStream
var command_runtime: BattleCommandRuntime
var move_indicator: MoveDestinationIndicator
var targeting_preview: AbilityTargetingPreview
var motor: CommandMotor
var player_controller: MobaPlayerController
var pathfinder: ArenaPathfinder
var returning_to_launcher := false
var match_authority: MatchAuthority
var authority_presentation: AuthorityEventPresentation
var dummy_regen_elapsed := 0.0


func _ready() -> void:
	match_authority = MatchAuthorityScript.new() as MatchAuthority
	match_authority.name = "MatchAuthority"
	add_child(match_authority)
	authority_presentation = AuthorityEventPresentationScript.new() as AuthorityEventPresentation
	authority_presentation.name = "AuthorityEventPresentation"
	add_child(authority_presentation)
	authority_presentation.setup(match_authority)
	arena = ArenaScript.new() as ArenaWorld
	arena.title = "CHARACTER LAB"
	arena.configure(BrawlMapCatalog.default_test_map())
	arena.show_measurement_marker = true
	add_child(arena)
	command_stream = BattleCommandStream.new()
	add_child(command_stream)
	pathfinder = ArenaPathfinder.new()
	pathfinder.configure(arena.map_definition.playable_bounds(0.25), arena.navigation_obstacles)
	command_runtime = CommandRuntimeScript.new() as BattleCommandRuntime
	command_runtime.name = "BattleCommandRuntime"
	add_child(command_runtime)
	command_runtime.setup(command_stream, pathfinder)
	command_runtime.movement_destination_resolved.connect(_on_movement_destination_resolved)
	command_runtime.command_processed.connect(_on_hero_command_processed)
	move_indicator = MoveIndicatorScript.new() as MoveDestinationIndicator
	move_indicator.name = "MoveDestinationIndicator"
	add_child(move_indicator)
	targeting_preview = TargetingPreviewScript.new() as AbilityTargetingPreview
	targeting_preview.name = "AbilityTargetingPreview"
	add_child(targeting_preview)
	_spawn_lab_hero("cheems_samurai")
	dummy = ActorScript.new() as CombatActor
	add_child(dummy)
	var dummy_definition := PlaceholderHero.create()
	dummy_definition.max_hp = 250.0
	dummy.setup(dummy_definition, 2, "训练假人", CombatActor.Relation.ENEMY)
	dummy.battle_id = 2
	dummy.global_position = Vector3(0.2, 0.05, 0.8)
	dummy.facing = Vector3.LEFT
	match_authority.register_entity(dummy, &"actor", dummy.battle_id, dummy.authoritative_actor_state())
	_connect_events(dummy)
	_build_lab_ui()
	_log("3D 实验室就绪：红=Hitbox，绿=Hurtbox，蓝=Pushbox")


func _connect_events(actor: CombatActor) -> void:
	actor.action_started.connect(func(_who: CombatActor, action: String) -> void: _log("%s 开始 %s" % [actor.actor_name, action]))
	actor.damaged.connect(func(_who: CombatActor, amount: float) -> void: _log("%s 受到 %.0f 伤害" % [actor.actor_name, amount]))
	actor.defeated.connect(func(_who: CombatActor) -> void: _log("%s 被击败" % actor.actor_name))


func _build_lab_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var header := Label.new()
	header.position = Vector2(38.0, 18.0)
	header.size = Vector2(750.0, 64.0)
	header.text = "CHARACTER LAB · GODOT 3D SPACE\n右键移动 · 左键普攻/确认技能 · QWER · F1 主菜单 · F3 判定体积"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color("e2f4ff"))
	layer.add_child(header)

	var panel := PanelContainer.new()
	panel.position = Vector2(890.0, 14.0)
	panel.size = Vector2(370.0, 692.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.15, 0.96)
	panel_style.border_color = Color("40566b")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var title := Label.new()
	title.text = "动作触发器"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var hero_row := HBoxContainer.new()
	column.add_child(hero_row)
	var hero_caption := Label.new()
	hero_caption.text = "调试角色  "
	hero_row.add_child(hero_caption)
	var hero_select := OptionButton.new()
	for id in HeroCatalog.IDS:
		hero_select.add_item(HeroCatalog.display_name(id))
		hero_select.set_item_metadata(hero_select.item_count - 1, id)
	hero_select.select(1)
	hero_select.item_selected.connect(func(index: int) -> void: _spawn_lab_hero(str(hero_select.get_item_metadata(index))))
	hero_row.add_child(hero_select)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 7)
	action_grid.add_theme_constant_override("v_separation", 7)
	column.add_child(action_grid)
	_add_action_button(action_grid, "普攻", func() -> void: _submit_lab_ability("basic"))
	_add_action_button(action_grid, "Q 技能", func() -> void: _submit_lab_ability("skill_q"))
	_add_action_button(action_grid, "松开 Q", func() -> void: _submit_lab_release("skill_q"))
	_add_action_button(action_grid, "W 技能", func() -> void: _submit_lab_ability("skill_w"))
	_add_action_button(action_grid, "松开 W", func() -> void: _submit_lab_release("skill_w"))
	_add_action_button(action_grid, "E 技能", func() -> void: _submit_lab_ability("skill_e"))
	_add_action_button(action_grid, "R 大招", func() -> void: _submit_lab_ability("ultimate"))
	_add_action_button(action_grid, "跳跃", _submit_lab_jump)
	_add_action_button(action_grid, "翻滚", _lab_roll)
	_add_action_button(action_grid, "假人跳跃", func() -> void: dummy.try_jump(true))
	_add_action_button(action_grid, "假人靠近", func() -> void: dummy.global_position = hero.global_position + hero.facing * 1.25)
	_add_action_button(action_grid, "假人：眩晕", func() -> void: dummy.apply_status(CombatStatuses.stunned(1.0), hero.battle_id))
	_add_action_button(action_grid, "假人：减速", func() -> void: dummy.apply_status(CombatStatuses.slow(2.5, 0.45), hero.battle_id))
	_add_action_button(action_grid, "假人：中毒", func() -> void: dummy.apply_status(CombatStatuses.poison(3.0), hero.battle_id))
	_add_action_button(action_grid, "自身：霸体", func() -> void: hero.apply_status(CombatStatuses.control_immune(1.5), hero.battle_id))
	_add_action_button(action_grid, "自身：无法选中", func() -> void: hero.apply_status(CombatStatuses.untargetable(1.5), hero.battle_id))
	_add_action_button(action_grid, "自身：死亡", _lab_defeat)
	bypass_check = CheckButton.new()
	bypass_check.text = "忽略消耗与 CD"
	bypass_check.button_pressed = true
	column.add_child(bypass_check)
	var debug_check := CheckButton.new()
	debug_check.text = "显示 3D 判定体积"
	debug_check.button_pressed = CombatActor.debug_shapes
	debug_check.toggled.connect(_set_debug_shapes)
	column.add_child(debug_check)
	var speed_row := HBoxContainer.new()
	column.add_child(speed_row)
	var speed_text := Label.new()
	speed_text.text = "播放速度  "
	speed_row.add_child(speed_text)
	var speed_select := OptionButton.new()
	speed_select.add_item("1.0×")
	speed_select.add_item("0.5×")
	speed_select.add_item("0.2×")
	speed_select.item_selected.connect(_speed_selected)
	speed_row.add_child(speed_select)
	var utility_row := HBoxContainer.new()
	column.add_child(utility_row)
	var reset_button := Button.new()
	reset_button.text = "全部重置"
	reset_button.pressed.connect(_reset_lab)
	utility_row.add_child(reset_button)
	var face_button := Button.new()
	face_button.text = "面向假人"
	face_button.pressed.connect(_face_dummy)
	utility_row.add_child(face_button)
	var menu_button := Button.new()
	menu_button.text = "返回菜单"
	menu_button.pressed.connect(_return_to_launcher)
	utility_row.add_child(menu_button)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(320.0, 66.0)
	status_label.add_theme_font_size_override("font_size", 14)
	column.add_child(status_label)
	column.add_child(HSeparator.new())
	event_label = Label.new()
	event_label.custom_minimum_size = Vector2(320.0, 48.0)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.add_theme_font_size_override("font_size", 12)
	event_label.add_theme_color_override("font_color", Color("91a7ba"))
	column.add_child(event_label)


func _add_action_button(parent: GridContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(155.0, 32.0)
	button.pressed.connect(callback)
	parent.add_child(button)


func _lab_roll() -> void:
	if hero == null:
		return
	hero.ignore_ability_requirements = bypass_check != null and bypass_check.button_pressed
	var command := BattleCommand.create(hero.battle_id, BattleCommand.Type.ROLL)
	command.direction = hero.facing
	command_stream.submit(command)


func _on_movement_destination_resolved(actor_id: int, requested: Vector3, resolved: Vector3, reachable: bool) -> void:
	if hero != null and actor_id == hero.battle_id and move_indicator != null:
		move_indicator.show_destination(requested, resolved, reachable)


func _on_hero_command_processed(command: BattleCommand, accepted: bool) -> void:
	if not accepted or hero == null or command.actor_id != hero.battle_id or move_indicator == null:
		return
	if command.type != BattleCommand.Type.MOVE_TO:
		move_indicator.clear_destination(true)


func _submit_lab_jump() -> void:
	if hero == null:
		return
	command_stream.submit(BattleCommand.create(hero.battle_id, BattleCommand.Type.JUMP))


func _submit_lab_ability(ability_id: String) -> void:
	if hero == null:
		return
	hero.ignore_ability_requirements = bypass_check != null and bypass_check.button_pressed
	var ability := hero.ability_by_id(ability_id)
	if ability == null or ability.disabled:
		return
	var target := hero.global_position + hero.facing
	if dummy != null and is_instance_valid(dummy):
		target = dummy.global_position
	var type := BattleCommand.Type.BEGIN_ABILITY if ability.hold_to_channel else BattleCommand.Type.CAST_ABILITY
	var command := BattleCommand.create(hero.battle_id, type, target)
	command.ability_id = ability_id
	command_stream.submit(command)


func _submit_lab_release(ability_id: String) -> void:
	if hero == null:
		return
	var command := BattleCommand.create(hero.battle_id, BattleCommand.Type.END_ABILITY)
	command.ability_id = ability_id
	command_stream.submit(command)


func _lab_defeat() -> void:
	if hero.is_defeated:
		return
	var basic := dummy.definition.ability_by_id("basic")
	hero.receive_hit(dummy, basic, -hero.facing, 0, hero.definition.max_hp + 1.0)


func _process(delta: float) -> void:
	if status_label == null:
		return
	_update_dummy_regeneration(delta)
	var bypass_enabled := bypass_check != null and bypass_check.button_pressed
	hero.ignore_ability_requirements = bypass_enabled
	if bypass_enabled:
		var resources_changed := not is_equal_approx(hero.energy, hero.definition.max_energy)
		hero.energy = hero.definition.max_energy
		for ability_id in hero.cooldowns.keys():
			if float(hero.cooldowns[ability_id]) > 0.0:
				resources_changed = true
			hero.cooldowns[ability_id] = 0.0
		if resources_changed:
			hero.resource_changed.emit(hero)
	var resource_text := "体力 %.0f" % hero.stamina
	if hero.definition.max_energy > 0.0 and not hero.definition.status_bar_id.is_empty():
		resource_text += "  %s %.0f" % [hero.definition.status_bar_label, hero.energy]
	status_label.text = "英雄：%s\nHP %.0f/%.0f  %s\n世界坐标 (%.2f, %.2f, %.2f)\n状态：%s\nCD  Q %.1f / W %.1f / E %.1f / R %.1f" % [
		hero.definition.display_name, hero.hp, hero.definition.max_hp, resource_text,
		hero.global_position.x, hero.global_position.y, hero.global_position.z, hero.status_text(),
		float(hero.cooldowns.get("skill_q", 0.0)), float(hero.cooldowns.get("skill_w", 0.0)),
		float(hero.cooldowns.get("skill_e", 0.0)), float(hero.cooldowns.get("ultimate", 0.0)),
	]


func _update_dummy_regeneration(delta: float) -> void:
	if dummy == null or not is_instance_valid(dummy) or dummy.is_defeated or dummy.hp >= dummy.definition.max_hp:
		dummy_regen_elapsed = 0.0
		return
	dummy_regen_elapsed += delta
	while dummy_regen_elapsed >= 1.0:
		dummy_regen_elapsed -= 1.0
		dummy.heal(30.0, dummy.battle_id)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			_return_to_launcher()
		elif event.keycode == KEY_F3:
			_set_debug_shapes(not CombatActor.debug_shapes)
			get_viewport().set_input_as_handled()


func _spawn_lab_hero(hero_id: String) -> void:
	var spawn_position := Vector3(-3.5, 0.05, 0.8)
	if hero != null:
		spawn_position = hero.global_position
		match_authority.unregister_entity(hero.entity_id, &"hero_changed")
		hero.queue_free()
	if player_controller != null:
		player_controller.queue_free()
	if command_runtime != null:
		command_runtime.unregister_actor(1)
	command_stream.reset()
	hero = ActorScript.new() as CombatActor
	add_child(hero)
	var definition := HeroCatalog.create(hero_id)
	hero.setup(definition, 1, definition.display_name, CombatActor.Relation.SELF)
	hero.battle_id = 1
	hero.energy = definition.max_energy
	hero.ignore_ability_requirements = true
	hero.global_position = spawn_position
	hero.facing = Vector3.RIGHT
	match_authority.register_entity(hero, &"actor", hero.battle_id, hero.authoritative_actor_state())
	_connect_events(hero)
	motor = command_runtime.register_actor(hero)
	move_indicator.setup(hero)
	player_controller = MobaPlayerController.new()
	add_child(player_controller)
	player_controller.setup(hero, arena, command_stream)
	targeting_preview.setup(hero, player_controller)
	_log("切换调试角色：%s" % definition.display_name)


func _set_debug_shapes(value: bool) -> void:
	CombatActor.debug_shapes = value
	get_tree().call_group("debug_visuals", "refresh_debug_visibility")


func _speed_selected(index: int) -> void:
	Engine.time_scale = [1.0, 0.5, 0.2][index]


func _reset_lab() -> void:
	for effect in get_tree().get_nodes_in_group("transient_combat_vfx"):
		effect.queue_free()
	command_stream.reset()
	command_runtime.stop_all()
	move_indicator.clear_destination()
	targeting_preview.clear()
	hero.reset_runtime(Vector3(-3.5, 0.05, 0.8))
	dummy.reset_runtime(Vector3(0.2, 0.05, 0.8))
	hero.facing = Vector3.RIGHT
	dummy.facing = Vector3.LEFT
	_log("角色与资源已重置")


func _face_dummy() -> void:
	var direction := dummy.global_position - hero.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		hero.facing = direction.normalized()
		dummy.facing = -hero.facing


func _log(text: String) -> void:
	event_lines.push_front(text)
	if event_lines.size() > 5:
		event_lines.resize(5)
	if event_label != null:
		event_label.text = "事件记录\n" + "\n".join(event_lines)


func _return_to_launcher() -> void:
	if returning_to_launcher:
		return
	returning_to_launcher = true
	Engine.time_scale = 1.0
	set_process_input(false)
	if player_controller != null:
		player_controller.set_process_unhandled_input(false)
	if command_runtime != null:
		command_runtime.running = false
		command_runtime.stop_all()
	get_tree().change_scene_to_file.bind("res://scenes/launcher.tscn").call_deferred()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
