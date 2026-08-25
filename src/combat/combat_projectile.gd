class_name CombatProjectile
extends Area3D

var source: CombatActor
var ability: AbilityDefinition
var direction := Vector3.FORWARD
var attack_id := 0
var remaining := 1.0
var current_speed := 0.0
var hit_targets: Dictionary = {}
var debug_mesh: MeshInstance3D
var visual: MeshInstance3D
var cable_visual: MeshInstance3D
var homing_target: CombatActor


func configure(p_source: CombatActor, p_ability: AbilityDefinition, p_direction: Vector3, p_attack_id: int, p_homing_target: CombatActor = null) -> void:
	source = p_source
	ability = p_ability
	direction = Vector3(p_direction.x, 0.0, p_direction.z).normalized()
	attack_id = p_attack_id
	homing_target = p_homing_target
	remaining = ability.projectile_lifetime
	current_speed = ability.projectile_speed
	collision_layer = 8
	collision_mask = 11 # World + Hurtbox + other projectiles.
	monitoring = true
	monitorable = true
	add_to_group("combat_projectiles")
	add_to_group("debug_visuals")
	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = ability.projectile_radius
	shape_node.shape = shape
	add_child(shape_node)
	visual = MeshInstance3D.new()
	if ability.vfx_id == "sword_wave":
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.16, 1.20, 0.12)
		pillar_mesh.material = _projectile_material(Color(0.94, 0.99, 1.0, 0.96))
		visual.mesh = pillar_mesh
		visual.rotation.y = atan2(-direction.x, -direction.z)
		visual.position.y = 0.08
		var glow := MeshInstance3D.new()
		var glow_mesh := BoxMesh.new()
		glow_mesh.size = Vector3(0.25, 1.28, 0.20)
		glow_mesh.material = _projectile_material(Color(0.42, 0.82, 1.0, 0.24))
		glow.mesh = glow_mesh
		visual.add_child(glow)
		var light := OmniLight3D.new()
		light.light_color = Color("9feaff")
		light.light_energy = 2.2
		light.omni_range = 2.1
		light.shadow_enabled = false
		visual.add_child(light)
		var trail := MeshInstance3D.new()
		trail.mesh = _exponential_trail_mesh()
		trail.rotation.y = visual.rotation.y
		add_child(trail)
	elif ability.vfx_id == "bear_throw_knife":
		var blade := BoxMesh.new()
		blade.size = Vector3(0.07, 0.035, 0.34)
		blade.material = _projectile_material(Color(0.82, 0.88, 0.86))
		visual.mesh = blade
		visual.rotation.y = atan2(-direction.x, -direction.z)
		var handle := MeshInstance3D.new()
		var handle_mesh := BoxMesh.new()
		handle_mesh.size = Vector3(0.09, 0.055, 0.15)
		handle_mesh.material = _projectile_material(Color("26302b"))
		handle.mesh = handle_mesh
		handle.position.z = 0.23
		visual.add_child(handle)
	elif ability.vfx_id == "chu_ying_homing_stone":
		var stone := CylinderMesh.new()
		stone.top_radius = ability.projectile_radius
		stone.bottom_radius = ability.projectile_radius
		stone.height = 0.048
		stone.radial_segments = 28
		stone.material = _projectile_material(Color("f0f2f5") if attack_id % 2 == 0 else Color("181b21"))
		visual.mesh = stone
		visual.rotation.x = PI * 0.5
	elif ability.vfx_id == "nailoong_fire_breath":
		var flame := SphereMesh.new()
		flame.radius = ability.projectile_radius
		flame.height = ability.projectile_radius * 2.0
		flame.material = _projectile_material(Color(1.0, 0.28, 0.025, 0.94))
		visual.mesh = flame
		visual.scale = Vector3(1.45, 0.88, 1.0)
		var core := MeshInstance3D.new()
		var core_mesh := SphereMesh.new()
		core_mesh.radius = ability.projectile_radius * 0.55
		core_mesh.height = ability.projectile_radius * 1.10
		core_mesh.material = _projectile_material(Color(1.0, 0.88, 0.22, 0.98))
		core.mesh = core_mesh
		visual.add_child(core)
		var light := OmniLight3D.new()
		light.light_color = Color("ff7a26")
		light.light_energy = 1.7
		light.omni_range = 1.15
		light.shadow_enabled = false
		visual.add_child(light)
	elif ability.vfx_id == "bear_grapple":
		var hook := SphereMesh.new()
		hook.radius = 0.12
		hook.height = 0.24
		hook.material = _projectile_material(Color("9caaa2"))
		visual.mesh = hook
		visual.rotation.y = atan2(-direction.x, -direction.z)
		for side in [-1.0, 1.0]:
			var prong := MeshInstance3D.new()
			var prong_mesh := BoxMesh.new()
			prong_mesh.size = Vector3(0.045, 0.045, 0.22)
			prong_mesh.material = _projectile_material(Color("c8d2cc"))
			prong.mesh = prong_mesh
			prong.position = Vector3(side * 0.09, 0.0, -0.13)
			prong.rotation.y = side * 0.46
			visual.add_child(prong)
		_create_grapple_cable()
	else:
		var sphere := SphereMesh.new()
		sphere.radius = ability.projectile_radius
		sphere.height = ability.projectile_radius * 2.0
		sphere.material = _projectile_material(ability.color)
		visual.mesh = sphere
	add_child(visual)
	debug_mesh = MeshInstance3D.new()
	var debug_sphere := SphereMesh.new()
	debug_sphere.radius = ability.projectile_radius * 1.08
	debug_sphere.height = ability.projectile_radius * 2.16
	debug_sphere.material = _projectile_material(Color(1.0, 0.1, 0.08, 0.3))
	debug_mesh.mesh = debug_sphere
	debug_mesh.visible = CombatActor.debug_shapes
	add_child(debug_mesh)


func _physics_process(delta: float) -> void:
	if ability.projectile_homing and homing_target != null and is_instance_valid(homing_target) and not homing_target.is_defeated:
		var target_direction := homing_target.global_position - global_position
		target_direction.y = 0.0
		if target_direction.length_squared() > 0.001:
			direction = target_direction.normalized()
	var next_position := global_position + direction * current_speed * delta
	# Continuous segment query prevents fast projectiles tunnelling through thin walls.
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var wall_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall_hit.is_empty():
		if ability.vfx_id == "bear_grapple" and source != null:
			source.begin_grapple_pull(Vector3(wall_hit["position"]) - direction * (source.definition.body_radius + 0.08))
			_spawn_grapple_impact(Vector3(wall_hit["position"]))
		queue_free()
		return
	# Hurtboxes are Areas rather than physics bodies. Query the travelled segment as
	# well as the overlap at its end so small, fast knives cannot step over a target.
	var actor_query := PhysicsRayQueryParameters3D.create(global_position, next_position, 2)
	actor_query.collide_with_areas = true
	actor_query.collide_with_bodies = false
	var actor_hit := get_world_3d().direct_space_state.intersect_ray(actor_query)
	if not actor_hit.is_empty():
		var collider = actor_hit.get("collider")
		var ray_target = collider.get_meta("combat_actor", null) if collider is Area3D else null
		if ray_target is CombatActor and _try_hit(ray_target as CombatActor):
			if not ability.projectile_pierces_actors:
				queue_free()
				return
	global_position = next_position
	if ability.projectile_deceleration > 0.0:
		current_speed = maxf(0.0, current_speed - ability.projectile_deceleration * delta)
	if ability.vfx_id == "bear_throw_knife" and visual != null:
		visual.rotation.z += delta * 21.0
	elif ability.vfx_id == "bear_grapple":
		_update_grapple_cable()
	remaining -= delta
	for area in get_overlapping_areas():
		if ability.projectile_destroyer and area is CombatProjectile:
			var other := area as CombatProjectile
			if other.source != null and other.source.team != source.team:
				other.queue_free()
				continue
		var target = area.get_meta("combat_actor", null)
		if target is CombatActor and _try_hit(target):
			if not ability.projectile_pierces_actors:
				queue_free()
				return
	for body in get_overlapping_bodies():
		if body is StaticBody3D:
			queue_free()
			return
	if remaining <= 0.0:
		queue_free()


func _try_hit(target: CombatActor) -> bool:
	if target == source or target.team == source.team or hit_targets.has(target.get_instance_id()):
		return false
	hit_targets[target.get_instance_id()] = true
	var hp_before := target.hp
	if target.receive_hit(source, ability, direction, attack_id):
		if ability.apply_stun_duration > 0.0:
			target.apply_status(CombatStatuses.stunned(ability.apply_stun_duration), source.battle_id)
		source.on_ability_hit(ability, minf(hp_before, ability.damage))
		if ability.vfx_id == "bear_grapple":
			var endpoint := target.global_position - direction * (source.definition.body_radius + target.definition.body_radius + 0.10)
			source.begin_grapple_pull(endpoint)
			_spawn_grapple_impact(target.global_position + Vector3.UP * 0.85)
		return true
	return false


func _create_grapple_cable() -> void:
	cable_visual = MeshInstance3D.new()
	cable_visual.top_level = true
	cable_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cable := CylinderMesh.new()
	cable.top_radius = 0.018
	cable.bottom_radius = 0.018
	cable.height = 1.0
	cable.radial_segments = 8
	cable.material = _projectile_material(Color(0.52, 0.60, 0.56, 0.92))
	cable_visual.mesh = cable
	add_child(cable_visual)
	_update_grapple_cable()


func _update_grapple_cable() -> void:
	if cable_visual == null or source == null or not is_instance_valid(source):
		return
	var start := source.global_position + Vector3.UP * 1.02 + source.facing * 0.30
	var finish := global_position
	var delta := finish - start
	var length := delta.length()
	if length <= 0.001:
		cable_visual.visible = false
		return
	cable_visual.visible = true
	var up := delta / length
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() <= 0.001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(up).normalized()
	cable_visual.global_transform = Transform3D(Basis(right, up, forward), (start + finish) * 0.5)
	cable_visual.scale = Vector3(1.0, length, 1.0)


func _spawn_grapple_impact(position: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.top_level = true
	ring.add_to_group("transient_combat_vfx")
	get_parent().add_child(ring)
	ring.global_position = position
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.10
	mesh.outer_radius = 0.16
	mesh.rings = 20
	mesh.ring_segments = 6
	mesh.material = _projectile_material(Color(0.70, 0.86, 0.76, 0.88))
	ring.mesh = mesh
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.5, 0.18)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.18)
	tween.tween_callback(ring.queue_free)


func refresh_debug_visibility() -> void:
	if debug_mesh != null:
		debug_mesh.visible = CombatActor.debug_shapes


func _projectile_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 3.2 if ability != null and ability.vfx_id == "sword_wave" else 1.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _exponential_trail_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 14
	var trail_length := 2.25
	var half_width := 0.08
	var bottom := -0.52
	for index in range(segments):
		var distance_0 := trail_length * float(index) / segments
		var distance_1 := trail_length * float(index + 1) / segments
		var height_0 := 1.20 * exp(-1.75 * distance_0)
		var height_1 := 1.20 * exp(-1.75 * distance_1)
		var alpha_0 := 0.58 * exp(-1.35 * distance_0)
		var alpha_1 := 0.58 * exp(-1.35 * distance_1)
		var bottom_0_left := Vector3(-half_width, bottom, distance_0)
		var bottom_0_right := Vector3(half_width, bottom, distance_0)
		var top_0_left := Vector3(-half_width, bottom + height_0, distance_0)
		var top_0_right := Vector3(half_width, bottom + height_0, distance_0)
		var bottom_1_left := Vector3(-half_width, bottom, distance_1)
		var bottom_1_right := Vector3(half_width, bottom, distance_1)
		var top_1_left := Vector3(-half_width, bottom + height_1, distance_1)
		var top_1_right := Vector3(half_width, bottom + height_1, distance_1)
		var vertices := [
			top_0_left, top_0_right, top_1_right, top_0_left, top_1_right, top_1_left,
			bottom_0_left, top_0_left, top_1_left, bottom_0_left, top_1_left, bottom_1_left,
			top_0_right, bottom_0_right, bottom_1_right, top_0_right, bottom_1_right, top_1_right,
		]
		var alphas := [
			alpha_0, alpha_0, alpha_1, alpha_0, alpha_1, alpha_1,
			alpha_0, alpha_0, alpha_1, alpha_0, alpha_1, alpha_1,
			alpha_0, alpha_0, alpha_1, alpha_0, alpha_1, alpha_1,
		]
		for vertex_index in range(vertices.size()):
			surface.set_color(Color(0.62, 0.91, 1.0, alphas[vertex_index]))
			surface.add_vertex(vertices[vertex_index])
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh
