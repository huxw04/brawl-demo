class_name WorldCombatNumber
extends Label3D

const LIFETIME := 0.82

var elapsed := 0.0
var start_position := Vector3.ZERO
var drift_direction := Vector3.UP


func setup(target: CombatActor, amount: float, kind: String, lateral_index: int) -> void:
	name = "WorldCombatNumber"
	top_level = true
	text = "+%d" % maxi(1, roundi(amount)) if kind == "heal" else "%d" % maxi(1, roundi(amount))
	font_size = 21
	pixel_size = 0.0085
	outline_size = 4
	modulate = _number_color(amount, kind)
	outline_modulate = Color(0.015, 0.02, 0.025, 0.88)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	var camera := get_viewport().get_camera_3d()
	var screen_right := Vector3.RIGHT
	if camera != null:
		screen_right = camera.global_basis.x.normalized()
	var lanes: Array[float] = [-0.18, 0.13, -0.07, 0.22, 0.04]
	var lane: float = lanes[posmod(lateral_index, lanes.size())]
	start_position = target.global_position + Vector3.UP * (target.definition.body_height + 0.38) + screen_right * lane
	global_position = start_position
	drift_direction = (Vector3.UP * 0.62 + screen_right * lane * 0.45).normalized()
	scale = Vector3.ONE * 0.82
	add_to_group("world_combat_numbers")


func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / LIFETIME, 0.0, 1.0)
	global_position = start_position + drift_direction * (0.62 * (1.0 - pow(1.0 - progress, 2.0)))
	var pop := 1.0 + sin(minf(progress / 0.22, 1.0) * PI) * 0.18
	scale = Vector3.ONE * pop
	modulate.a = 1.0 - smoothstep(0.58, 1.0, progress)
	if elapsed >= LIFETIME:
		queue_free()


func _number_color(amount: float, kind: String) -> Color:
	if kind == "heal":
		return Color("69e58a")
	return Color("ffad63") if amount >= 20.0 else Color("fff1c2")
