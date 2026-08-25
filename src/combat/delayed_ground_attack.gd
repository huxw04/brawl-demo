class_name DelayedGroundAttack
extends Node3D

var source: CombatActor
var ability: AbilityDefinition
var attack_id := 0
var remaining := 0.0
var radius := 1.0
var indicator: MeshInstance3D


func configure(p_source: CombatActor, p_ability: AbilityDefinition, p_attack_id: int, center: Vector3) -> void:
	source = p_source
	ability = p_ability
	attack_id = p_attack_id
	remaining = ability.delayed_delay
	radius = ability.delayed_radius
	top_level = true
	global_position = Vector3(center.x, 0.065, center.z)
	add_to_group("transient_combat_vfx")
	_spawn_indicator()


func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining > 0.0:
		return
	_detonate()
	set_physics_process(false)
	queue_free()


func _spawn_indicator() -> void:
	indicator = MeshInstance3D.new()
	indicator.name = "DelayedGroundCircle"
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.018
	disc.radial_segments = 64
	disc.material = _material(Color(0.95, 0.07, 0.035, 1.0))
	indicator.mesh = disc
	add_child(indicator)
	var tween := indicator.create_tween()
	tween.tween_property(indicator, "transparency", 0.70, maxf(remaining, 0.01))


func _detonate() -> void:
	if not is_instance_valid(source):
		return
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * ability.delayed_center_y)
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit_targets: Dictionary = {}
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var collider = result.get("collider")
		if not collider is Area3D:
			continue
		var target = (collider as Area3D).get_meta("combat_actor", null)
		if not target is CombatActor or target == source or target.team == source.team:
			continue
		var target_id: int = target.get_instance_id()
		if hit_targets.has(target_id):
			continue
		hit_targets[target_id] = true
		var direction: Vector3 = target.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() <= 0.001:
			direction = source.facing
		var hp_before: float = target.hp
		if target.receive_hit(source, ability, direction.normalized(), attack_id, ability.delayed_damage):
			source.on_ability_hit(ability, minf(hp_before, ability.delayed_damage))
	_spawn_shockwave()


func _spawn_shockwave() -> void:
	var wave := MeshInstance3D.new()
	wave.name = "DelayedGroundShockwave"
	wave.top_level = true
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(wave)
	wave.global_position = global_position + Vector3.UP * 0.025
	var ring := TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 1.0
	ring.rings = 64
	ring.ring_segments = 10
	ring.material = _material(Color(1.0, 0.25, 0.16, 0.82))
	wave.mesh = ring
	wave.scale = Vector3.ONE * radius * 0.20
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3.ONE * radius * 1.18, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(wave, "transparency", 1.0, 0.28)
	tween.tween_callback(wave.queue_free)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material
