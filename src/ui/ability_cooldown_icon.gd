class_name AbilityCooldownIcon
extends Control

var actor: CombatActor
var ability_id := ""
var key_label := "Q"
var selected := false
var radius := 29.0


func setup(p_actor: CombatActor, p_ability_id: String, p_key_label: String) -> void:
	actor = p_actor
	ability_id = p_ability_id
	key_label = p_key_label
	custom_minimum_size = Vector2(72.0, 78.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if actor == null:
		return
	var center := Vector2(36.0, 34.0)
	draw_circle(center, radius, Color("111923"))
	var ratio := actor.cooldown_ratio(ability_id)
	if ratio > 0.001:
		var water_top := -radius + radius * 2.0 * (1.0 - ratio)
		for local_y in range(int(ceil(water_top)), int(radius) + 1):
			var half_width := sqrt(maxf(0.0, radius * radius - float(local_y * local_y)))
			draw_line(
				center + Vector2(-half_width, float(local_y)),
				center + Vector2(half_width, float(local_y)),
				Color(0.26, 0.67, 0.9, 0.7),
				1.3,
			)
	var border := Color("ffe38a") if selected else Color("a7c8dd")
	draw_circle(center, radius, border, false, 3.5 if selected else 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-14.0, 8.0), key_label, HORIZONTAL_ALIGNMENT_CENTER, 28.0, 22, Color.WHITE)
	var ability := actor.ability_by_id(ability_id)
	if ability == null:
		ability = actor.definition.ability_by_id(ability_id)
	var name := "--" if ability == null else ability.display_name
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 75.0), name, HORIZONTAL_ALIGNMENT_CENTER, 72.0, 12, Color("b9c8d2"))
