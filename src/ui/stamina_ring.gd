class_name StaminaRing
extends Control

const TRACK_COLOR := Color(0.055, 0.095, 0.13, 0.92)
const BORDER_COLOR := Color(0.78, 0.95, 1.0, 0.88)
const STAMINA_COLOR := Color(0.52, 0.86, 0.95, 1.0)

var actor: CombatActor
var last_ratio := -1.0


func setup(p_actor: CombatActor) -> void:
	actor = p_actor
	custom_minimum_size = Vector2(58.0, 58.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	if actor == null or actor.definition == null:
		return
	var ratio := clampf(actor.stamina / maxf(actor.definition.max_stamina, 0.001), 0.0, 1.0)
	if not is_equal_approx(ratio, last_ratio):
		last_ratio = ratio
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 6.0
	draw_circle(center, radius - 4.0, Color(0.025, 0.045, 0.065, 0.78))
	draw_arc(center, radius + 2.0, 0.0, TAU, 64, BORDER_COLOR, 2.0, true)
	draw_arc(center, radius, 0.0, TAU, 64, TRACK_COLOR, 8.0, true)
	if last_ratio > 0.001:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * last_ratio, maxi(4, ceili(64.0 * last_ratio)), STAMINA_COLOR, 8.0, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-18.0, 5.0), "%d" % roundi(last_ratio * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 36.0, 13, Color("dff8ff"))
