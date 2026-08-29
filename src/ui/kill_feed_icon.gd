class_name KillFeedIcon
extends Control


func _ready() -> void:
	custom_minimum_size = Vector2(42.0, 58.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_draw_sword(Vector2(8.0, 8.0), Vector2(34.0, 49.0))
	_draw_sword(Vector2(34.0, 8.0), Vector2(8.0, 49.0))
	draw_circle(Vector2(21.0, 29.0), 3.6, Color("f06c62"))


func _draw_sword(tip: Vector2, handle: Vector2) -> void:
	var direction := (handle - tip).normalized()
	var normal := Vector2(-direction.y, direction.x)
	draw_line(tip, handle - direction * 8.0, Color("f5f0e8"), 4.2, true)
	draw_line(handle - direction * 12.0 - normal * 7.0, handle - direction * 12.0 + normal * 7.0, Color("f06c62"), 4.0, true)
	draw_line(handle - direction * 8.0, handle, Color("d5a04d"), 5.0, true)
