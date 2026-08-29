class_name NetworkQualityIcon
extends Control

var latency_ms := -1


func _ready() -> void:
	custom_minimum_size = Vector2(28.0, 22.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_update_tooltip()


func set_latency(value: int) -> void:
	latency_ms = value
	_update_tooltip()
	queue_redraw()


func _draw() -> void:
	var center := Vector2(14.0, 19.0)
	var active_count := _active_arc_count()
	var active_color := _quality_color()
	var inactive_color := Color(0.36, 0.43, 0.48, 0.38)
	draw_circle(center, 2.1, active_color if active_count > 0 else inactive_color)
	for index in range(3):
		var color := active_color if index < active_count else inactive_color
		draw_arc(center, 5.0 + float(index) * 4.1, PI * 1.15, PI * 1.85, 18, color, 2.2, true)


func _active_arc_count() -> int:
	if latency_ms < 0:
		return 0
	if latency_ms <= 80:
		return 3
	if latency_ms <= 160:
		return 2
	return 1


func _quality_color() -> Color:
	if latency_ms < 0:
		return Color("78838c")
	if latency_ms <= 80:
		return Color("70e18b")
	if latency_ms <= 160:
		return Color("f0cf67")
	return Color("f17970")


func _update_tooltip() -> void:
	tooltip_text = "等待延迟数据" if latency_ms < 0 else "到房主的往返延迟：%d ms" % latency_ms
