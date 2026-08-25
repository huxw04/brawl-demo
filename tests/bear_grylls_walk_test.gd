extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := ArenaWorld.new()
	arena.include_test_walls = false
	root.add_child(arena)
	var hero := CombatActor.new()
	root.add_child(hero)
	hero.setup(BearGryllsJungler.create(), 1, "贝尔", CombatActor.Relation.SELF)
	hero.global_position = Vector3.ZERO
	hero.facing = Vector3.RIGHT
	await physics_frame
	_check(hero.sprite.texture == hero.definition.sprite_texture, "idle should use the standing texture")
	hero.set_move_intent(Vector2.RIGHT)
	await physics_frame
	var first_frame := hero.sprite.texture
	_check(first_frame == hero.definition.movement_sprite_textures[0], "movement should start on the first stride texture")
	await _frames(14)
	_check(hero.sprite.texture != first_frame, "movement should advance through the stride frames")
	hero.set_move_intent(Vector2.ZERO)
	await physics_frame
	_check(hero.sprite.texture == hero.definition.sprite_texture, "stopping should immediately restore standing texture")
	hero.queue_free()
	arena.queue_free()
	if failures.is_empty():
		print("Bear Grylls walk checks passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
