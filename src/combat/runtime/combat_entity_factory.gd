class_name CombatEntityFactory
extends RefCounted

const ProjectileScript = preload("res://src/combat/combat_projectile.gd")
const DelayedGroundAttackScript = preload("res://src/combat/delayed_ground_attack.gd")
const ChuYingStoneScript = preload("res://src/combat/chu_ying_stone.gd")
const ChuYingBarrierScript = preload("res://src/combat/chu_ying_barrier.gd")


static func spawn_projectile(
		authority: Node,
		parent: Node,
		source: CombatActor,
		ability: AbilityDefinition,
		direction: Vector3,
		attack_id: int,
		spawn_position: Vector3,
		homing_target: CombatActor = null
) -> CombatProjectile:
	var projectile := ProjectileScript.new() as CombatProjectile
	parent.add_child(projectile)
	projectile.global_position = spawn_position
	projectile.configure(source, ability, direction, attack_id, homing_target)
	_register(authority, projectile, &"projectile", _spawn_state(source, ability, attack_id, spawn_position, direction))
	return projectile


static func spawn_delayed_attack(
		authority: Node,
		parent: Node,
		source: CombatActor,
		ability: AbilityDefinition,
		attack_id: int,
		center: Vector3
) -> DelayedGroundAttack:
	var delayed := DelayedGroundAttackScript.new() as DelayedGroundAttack
	parent.add_child(delayed)
	delayed.configure(source, ability, attack_id, center)
	var initial_state := _spawn_state(source, ability, attack_id, delayed.global_position, source.facing)
	initial_state["remaining"] = ability.delayed_delay
	initial_state["radius"] = ability.delayed_radius
	_register(authority, delayed, &"delayed_attack", initial_state)
	return delayed


static func spawn_chu_ying_stone(
		authority: Node,
		parent: Node,
		source: CombatActor,
		ability: AbilityDefinition,
		attack_id: int,
		landing_position: Vector3
) -> ChuYingStone:
	var stone := ChuYingStoneScript.new() as ChuYingStone
	parent.add_child(stone)
	stone.configure(source, ability, landing_position, attack_id)
	var initial_state := _spawn_state(source, ability, attack_id, stone.global_position, Vector3.DOWN)
	initial_state["fall"] = stone.fall_remaining
	initial_state["remaining"] = stone.ground_remaining
	initial_state["flying"] = false
	_register(authority, stone, &"chu_ying_stone", initial_state)
	return stone


static func spawn_chu_ying_barrier(
		authority: Node,
		parent: Node,
		source: CombatActor,
		ability: AbilityDefinition,
		attack_id: int,
		center: Vector3,
		half_extents: Vector2
) -> ChuYingBarrier:
	var barrier := ChuYingBarrierScript.new() as ChuYingBarrier
	parent.add_child(barrier)
	barrier.configure(source, center, half_extents, attack_id)
	var initial_state := _spawn_state(source, ability, attack_id, barrier.global_position, source.facing)
	initial_state["half_extents"] = [half_extents.x, half_extents.y]
	initial_state["remaining"] = barrier.remaining
	_register(authority, barrier, &"chu_ying_barrier", initial_state)
	return barrier


static func _register(authority: Node, entity: Node, entity_kind: StringName, initial_state: Dictionary) -> void:
	if authority != null and authority.has_method("register_entity"):
		authority.call("register_entity", entity, entity_kind, 0, initial_state)


static func _spawn_state(
		source: CombatActor,
		ability: AbilityDefinition,
		attack_id: int,
		spawn_position: Vector3,
		spawn_direction: Vector3
) -> Dictionary:
	return {
		"source_id": source.battle_id,
		"ability_id": ability.ability_id,
		"vfx_id": ability.vfx_id,
		"attack_id": attack_id,
		"position": _vector_packet(spawn_position),
		"direction": _vector_packet(spawn_direction),
		"speed": ability.projectile_speed,
		"lifetime": ability.projectile_lifetime,
		"radius": ability.projectile_radius,
		"color": [ability.color.r, ability.color.g, ability.color.b, ability.color.a],
	}


static func _vector_packet(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
