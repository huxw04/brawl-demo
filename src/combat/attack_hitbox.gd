class_name AttackHitbox
extends Area3D

var source: CombatActor
var ability: AbilityDefinition
var attack_id := 0
var remaining := 0.0
var hit_targets: Dictionary = {}
var hit_counts: Dictionary = {}
var pulse_remaining := 0.0
var pulse_index := 0
var debug_mesh: MeshInstance3D
var damage_multiplier := 1.0


func configure(p_source: CombatActor, p_ability: AbilityDefinition, p_attack_id: int) -> void:
	source = p_source
	ability = p_ability
	attack_id = p_attack_id
	damage_multiplier = source.current_attack_damage_multiplier if ability.ability_id == "basic" else 1.0
	remaining = ability.active_duration_override if ability.active_duration_override > 0.0 else ability.active
	pulse_remaining = 0.0
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	add_to_group("debug_visuals")
	var shape_node := CollisionShape3D.new()
	if ability.hitbox_shape == "box":
		var shape := BoxShape3D.new()
		shape.size = ability.hitbox_size
		shape_node.shape = shape
	else:
		var shape := CylinderShape3D.new()
		shape.radius = ability.hitbox_radius
		shape.height = ability.hitbox_size.y
		shape_node.shape = shape
	add_child(shape_node)
	if ability.dash_distance > 0.0 and source.dash_phasing:
		top_level = true
		global_position = source.dash_start.lerp(source.dash_end, 0.5) + Vector3.UP * ability.hitbox_center_y
	else:
		position = (Vector3.ZERO if ability.hitbox_shape in ["circle", "arc"] else source.facing * ability.hitbox_distance) + Vector3.UP * ability.hitbox_center_y
	rotation.y = _facing_yaw(source.facing)
	debug_mesh = MeshInstance3D.new()
	var mesh: Mesh
	if ability.hitbox_shape == "box":
		var box := BoxMesh.new()
		box.size = ability.hitbox_size
		mesh = box
	elif ability.hitbox_shape == "arc":
		mesh = _arc_debug_mesh(ability.hitbox_radius, ability.hitbox_size.y, ability.arc_degrees)
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = ability.hitbox_radius
		cylinder.bottom_radius = ability.hitbox_radius
		cylinder.height = ability.hitbox_size.y
		cylinder.radial_segments = 40
		mesh = cylinder
	var debug_material := _debug_material(Color(1.0, 0.12, 0.08, 0.26))
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = debug_material
	else:
		(mesh as ArrayMesh).surface_set_material(0, debug_material)
	debug_mesh.mesh = mesh
	debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug_mesh.visible = CombatActor.debug_shapes
	add_child(debug_mesh)


func _physics_process(delta: float) -> void:
	remaining -= delta
	pulse_remaining -= delta
	if ability.hit_interval <= 0.0 or pulse_remaining <= 0.0:
		pulse_index += 1
		pulse_remaining += ability.hit_interval if ability.hit_interval > 0.0 else 0.0
		if ability.hit_interval > 0.0 and pulse_index <= ability.max_hits_per_target:
			source.on_hitbox_pulse(ability, pulse_index)
		for area in get_overlapping_areas():
			var target = area.get_meta("combat_actor", null)
			if target is CombatActor:
				_try_hit(target)
	if remaining <= 0.0:
		queue_free()


func _try_hit(target: CombatActor) -> void:
	var target_id := target.get_instance_id()
	if target == source or target.team == source.team or int(hit_counts.get(target_id, 0)) >= ability.max_hits_per_target:
		return
	if ability.hitbox_shape == "arc":
		var to_target := target.global_position - source.global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.001 and rad_to_deg(source.facing.angle_to(to_target.normalized())) > ability.arc_degrees * 0.5:
			return
	var pulse_damage := ability.damage
	if not ability.pulse_damage.is_empty():
		pulse_damage = ability.pulse_damage[mini(maxi(pulse_index - 1, 0), ability.pulse_damage.size() - 1)]
	var damage := pulse_damage * damage_multiplier
	if ability.execute_missing_hp_ratio > 0.0 and pulse_index >= ability.max_hits_per_target:
		damage += (target.definition.max_hp - target.hp) * ability.execute_missing_hp_ratio
	var hp_before := target.hp
	var hit_landed := false
	if damage <= 0.0:
		hit_landed = target.can_receive_attack()
	else:
		hit_landed = target.receive_hit(source, ability, source.facing, attack_id, damage)
	if hit_landed:
		hit_counts[target_id] = int(hit_counts.get(target_id, 0)) + 1
		hit_targets[target_id] = true
		if int(hit_counts[target_id]) == 1:
			if ability.apply_slow_ratio < 1.0:
				var slow_duration := ability.apply_slow_duration if ability.apply_slow_duration > 0.0 else maxf(ability.apply_root_duration, ability.active)
				target.apply_status(CombatStatuses.slow(slow_duration, ability.apply_slow_ratio), source.battle_id)
			if ability.apply_root_duration > 0.0:
				target.apply_status(CombatStatuses.rooted(ability.apply_root_duration), source.battle_id)
			if ability.apply_stun_duration > 0.0:
				var stun := CombatStatuses.stunned(ability.apply_stun_duration)
				if ability.apply_stun_delay > 0.0:
					target.apply_status_after(stun, ability.apply_stun_delay, source.battle_id)
				else:
					target.apply_status(stun, source.battle_id)
			if ability.target_delayed_damage_delay > 0.0 and ability.target_delayed_missing_hp_ratio > 0.0:
				target.queue_delayed_missing_hp_damage(source, ability, attack_id)
		source.on_ability_hit(ability, minf(hp_before, damage))


func refresh_debug_visibility() -> void:
	if debug_mesh != null:
		debug_mesh.visible = CombatActor.debug_shapes


func _facing_yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _arc_debug_mesh(radius: float, height: float, degrees: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := maxi(8, ceili(degrees / 10.0))
	var top_y := height * 0.5
	var bottom_y := -height * 0.5
	for index in range(segments):
		var angle_0 := deg_to_rad(-degrees * 0.5 + degrees * float(index) / segments)
		var angle_1 := deg_to_rad(-degrees * 0.5 + degrees * float(index + 1) / segments)
		var bottom_0 := Vector3(sin(angle_0) * radius, bottom_y, -cos(angle_0) * radius)
		var bottom_1 := Vector3(sin(angle_1) * radius, bottom_y, -cos(angle_1) * radius)
		var top_0 := Vector3(bottom_0.x, top_y, bottom_0.z)
		var top_1 := Vector3(bottom_1.x, top_y, bottom_1.z)
		for vertex in [Vector3(0.0, top_y, 0.0), top_0, top_1, Vector3(0.0, bottom_y, 0.0), bottom_1, bottom_0, bottom_0, bottom_1, top_1, bottom_0, top_1, top_0]:
			surface.add_vertex(vertex)
	return surface.commit()


func _debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
