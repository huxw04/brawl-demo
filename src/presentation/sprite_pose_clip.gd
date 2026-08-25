class_name SpritePoseClip
extends Resource

@export var duration := 0.5
@export var loop := false
var times := PackedFloat32Array()
var offsets := PackedVector2Array()
var scales := PackedVector2Array()
var angles := PackedFloat32Array()


func add_key(time: float, offset: Vector2, scale: Vector2, angle: float) -> SpritePoseClip:
	times.append(time)
	offsets.append(offset)
	scales.append(scale)
	angles.append(angle)
	return self


func sample(time: float) -> Dictionary:
	if times.is_empty():
		return {"offset": Vector2.ZERO, "scale": Vector2.ONE, "angle": 0.0}
	var local_time := fposmod(time, maxf(duration, 0.001)) if loop else clampf(time, 0.0, duration)
	if local_time <= times[0]:
		return _pose(0)
	for index in range(1, times.size()):
		if local_time <= times[index]:
			var alpha := inverse_lerp(times[index - 1], times[index], local_time)
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)
			return {
				"offset": offsets[index - 1].lerp(offsets[index], alpha),
				"scale": scales[index - 1].lerp(scales[index], alpha),
				"angle": lerpf(angles[index - 1], angles[index], alpha),
			}
	return _pose(times.size() - 1)


func _pose(index: int) -> Dictionary:
	return {"offset": offsets[index], "scale": scales[index], "angle": angles[index]}
