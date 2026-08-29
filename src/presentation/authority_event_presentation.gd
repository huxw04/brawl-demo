class_name AuthorityEventPresentation
extends Node

signal event_consumed(event: AuthoritativeEvent)

const ProjectileEventVisualScript = preload("res://src/presentation/projectile_event_visual.gd")
const WorldEntityEventVisualScript = preload("res://src/presentation/world_entity_event_visual.gd")

var authority: MatchAuthority
var event_source: Node
var last_consumed_event_id := 0
var consumed_packets: Array[Dictionary] = []
var entity_visuals: Dictionary = {}
var finished_entity_counts_by_kind: Dictionary = {}
var world_effect_counts_by_vfx: Dictionary = {}
var hero_effect_counts_by_vfx: Dictionary = {}
var match_rule_counts_by_kind: Dictionary = {}


func _ready() -> void:
	add_to_group("authority_event_presentation")


func setup(p_authority: MatchAuthority) -> void:
	authority = p_authority
	setup_source(p_authority)


func setup_source(p_event_source: Node) -> void:
	_disconnect_source()
	event_source = p_event_source
	last_consumed_event_id = 0
	consumed_packets.clear()
	finished_entity_counts_by_kind.clear()
	world_effect_counts_by_vfx.clear()
	hero_effect_counts_by_vfx.clear()
	match_rule_counts_by_kind.clear()
	_clear_entity_visuals()
	if event_source == null:
		return
	if event_source.has_signal("authoritative_event_emitted"):
		event_source.connect("authoritative_event_emitted", _consume_event)
	if event_source.has_signal("entity_replica_created"):
		event_source.connect("entity_replica_created", _on_entity_replica_created)
	if event_source.has_signal("entity_replica_removed"):
		event_source.connect("entity_replica_removed", _remove_entity_visual)


func replay(events: Array[AuthoritativeEvent]) -> void:
	for event in events:
		_consume_event(event)


func _consume_event(event: AuthoritativeEvent) -> void:
	if event == null or event.event_id <= last_consumed_event_id:
		return
	last_consumed_event_id = event.event_id
	consumed_packets.append(event.to_packet())
	if event.event_type == AuthoritativeEvent.ENTITY_SPAWNED:
		_consume_entity_spawn(event)
	elif event.event_type == AuthoritativeEvent.ENTITY_DESTROYED:
		_remove_entity_visual(event.entity_id, str(event.payload.get("reason", "removed")))
	elif event.event_type == AuthoritativeEvent.WORLD_EFFECT:
		_consume_world_effect(event.payload)
	elif event.event_type == AuthoritativeEvent.HERO_EFFECT:
		_consume_hero_effect(event.payload)
	elif event.event_type == AuthoritativeEvent.MATCH_RULE:
		_consume_match_rule(event.payload)
	event_consumed.emit(event)


func _consume_entity_spawn(event: AuthoritativeEvent) -> void:
	if event_source == null:
		return
	var initial_state: Dictionary = event.payload.get("initial_state", {})
	_present_entity(event.entity_id, str(event.payload.get("entity_kind", "")), initial_state)


func _on_entity_replica_created(entity_id: int, entity_kind: String, initial_state: Dictionary) -> void:
	_present_entity(entity_id, entity_kind, initial_state)


func _present_entity(entity_id: int, entity_kind: String, initial_state: Dictionary) -> void:
	if event_source == null or entity_kind not in ["projectile", "delayed_attack", "chu_ying_stone", "chu_ying_barrier"]:
		return
	var existing := entity_visuals.get(entity_id) as Node
	if existing != null and is_instance_valid(existing):
		return
	var target := event_source.call("entity", entity_id) as Node3D
	if target == null:
		return
	_remove_entity_visual(entity_id)
	var visual: Node3D
	if entity_kind == "projectile":
		visual = ProjectileEventVisualScript.new() as ProjectileEventVisual
		add_child(visual)
		(visual as ProjectileEventVisual).setup(entity_id, target, initial_state, event_source)
	else:
		visual = WorldEntityEventVisualScript.new() as WorldEntityEventVisual
		add_child(visual)
		(visual as WorldEntityEventVisual).setup(entity_id, entity_kind, target, initial_state, event_source)
	entity_visuals[entity_id] = visual


func _remove_entity_visual(entity_id: int, reason := "removed") -> void:
	var visual := entity_visuals.get(entity_id) as Node
	if visual != null and is_instance_valid(visual):
		var entity_kind_value = visual.get("entity_kind")
		if entity_kind_value is String:
			var kind := str(entity_kind_value)
			finished_entity_counts_by_kind[kind] = int(finished_entity_counts_by_kind.get(kind, 0)) + 1
		if visual.has_method("finish"):
			visual.call("finish", reason)
		visual.queue_free()
	entity_visuals.erase(entity_id)


func _consume_world_effect(payload: Dictionary) -> void:
	var vfx_id := str(payload.get("vfx_id", ""))
	if event_source == null or vfx_id != "chu_ying_board":
		return
	world_effect_counts_by_vfx[vfx_id] = int(world_effect_counts_by_vfx.get(vfx_id, 0)) + 1
	var source := event_source.call("entity", int(payload.get("source_id", 0))) as CombatActor
	if source == null or source.actor_presentation == null or not source.actor_presentation.hero_vfx is ChuYingVfx:
		return
	var packet = payload.get("position", [])
	if packet is Array and (packet as Array).size() >= 3:
		(source.actor_presentation.hero_vfx as ChuYingVfx).spawn_board(Vector3(float(packet[0]), float(packet[1]), float(packet[2])))


func _consume_hero_effect(payload: Dictionary) -> void:
	var vfx_id := str(payload.get("vfx_id", ""))
	if event_source == null or vfx_id.is_empty():
		return
	hero_effect_counts_by_vfx[vfx_id] = int(hero_effect_counts_by_vfx.get(vfx_id, 0)) + 1
	var source := event_source.call("entity", int(payload.get("source_id", 0))) as CombatActor
	if source == null or source.actor_presentation == null:
		return
	var hero_vfx := source.actor_presentation.hero_vfx
	match vfx_id:
		"ability_vfx":
			var ability := _resolve_effect_ability(source, payload)
			if ability != null:
				source.actor_presentation.spawn_ability_vfx(ability)
		"chu_ying_teleport_charge":
			if hero_vfx is ChuYingVfx:
				var duration := maxf(0.01, float(payload.get("duration", 1.0)))
				(hero_vfx as ChuYingVfx).spawn_teleport_charge(duration)
				source.actor_presentation.spawn_concentration_rings(float(payload.get("radius", 0.78)), duration, "ChuYingTeleportFocus")
		"chu_ying_teleport":
			if hero_vfx is ChuYingVfx:
				(hero_vfx as ChuYingVfx).spawn_teleport_ghost(_packet_vector(payload.get("start", [])))
				(hero_vfx as ChuYingVfx).spawn_teleport_ghost(_packet_vector(payload.get("finish", [])))
		"sword_shield_transform":
			source.actor_presentation.set_transformed_visual(bool(payload.get("active", true)))
			source.flash_remaining = 0.24
		"cheems_dimensional_focus":
			source.actor_presentation.spawn_concentration_rings(
				float(payload.get("radius", 2.0)), float(payload.get("duration", 0.5)), "CheemsUltimateFocus"
			)
		"cheems_dimensional_circle":
			if hero_vfx is CheemsVfx:
				var circle_ability := source.ability_by_id(str(payload.get("ability_id", "ultimate")))
				if circle_ability != null:
					(hero_vfx as CheemsVfx).spawn_magic_circle(circle_ability, float(payload.get("duration", circle_ability.startup + circle_ability.active)))
		"cheems_dimensional_cancel":
			if hero_vfx is CheemsVfx:
				(hero_vfx as CheemsVfx).dismiss_magic_circle(float(payload.get("duration", 0.06)))
		"cheems_dimensional_cut":
			if hero_vfx is CheemsVfx:
				var cut_ability := source.ability_by_id(str(payload.get("ability_id", "ultimate")))
				if cut_ability != null:
					(hero_vfx as CheemsVfx).spawn_dimensional_cut(cut_ability, int(payload.get("pulse_index", 0)))
		"cheems_multi_slash":
			if hero_vfx is CheemsVfx:
				var multi_ability := source.ability_by_id(str(payload.get("ability_id", "skill_w")))
				if multi_ability != null:
					(hero_vfx as CheemsVfx).start_horizontal_slashes(multi_ability, float(payload.get("duration", multi_ability.active)))
		"bear_poison_mark":
			var marked := event_source.call("entity", int(payload.get("target_id", 0))) as CombatActor
			if hero_vfx is BearVfx and marked != null:
				(hero_vfx as BearVfx).spawn_poison_mark(marked, float(payload.get("duration", 2.0)))
		"bear_poison_burst":
			var poisoned := event_source.call("entity", int(payload.get("target_id", 0))) as CombatActor
			if hero_vfx is BearVfx and poisoned != null:
				(hero_vfx as BearVfx).spawn_poison_burst(poisoned)
		"bear_backstab":
			var backstabbed := event_source.call("entity", int(payload.get("target_id", 0))) as CombatActor
			if hero_vfx is BearVfx and backstabbed != null:
				(hero_vfx as BearVfx).spawn_backstab_flash(backstabbed)
		"bear_ambush":
			if hero_vfx is BearVfx:
				var ambush_ability := source.ability_by_id(str(payload.get("ability_id", "ultimate")))
				if ambush_ability != null:
					var start := _packet_vector(payload.get("start", []))
					var finish := _packet_vector(payload.get("finish", []))
					(hero_vfx as BearVfx).spawn_afterimage(start, ambush_ability)
					(hero_vfx as BearVfx).spawn_teleport_trail(start, finish, ambush_ability)
					(hero_vfx as BearVfx).spawn_afterimage(finish, ambush_ability)
		"bear_grapple_pull":
			if hero_vfx is BearVfx:
				(hero_vfx as BearVfx).spawn_pull_streaks(_packet_vector(payload.get("start", [])), _packet_vector(payload.get("finish", [])))
		"sword_shield_block":
			if hero_vfx is SwordShieldVfx:
				(hero_vfx as SwordShieldVfx).spawn_block_flash()
		"nailoong_bounce":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_bounce_flash(_packet_vector(payload.get("position", [])))
		"nailoong_takeoff":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_takeoff_ring_at(_packet_vector(payload.get("position", [])))
		"nailoong_landing":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_landing_wave_at(_packet_vector(payload.get("position", [])), float(payload.get("radius", 1.5)))
		"nailoong_heal_tick":
			if hero_vfx is NailoongVfx:
				(hero_vfx as NailoongVfx).spawn_heal_tick_at(_packet_vector(payload.get("position", [])))


func _consume_match_rule(payload: Dictionary) -> void:
	var event_kind := str(payload.get("event_kind", ""))
	if event_source == null or event_kind.is_empty():
		return
	match_rule_counts_by_kind[event_kind] = int(match_rule_counts_by_kind.get(event_kind, 0)) + 1
	if event_kind != "actor_respawned":
		return
	var actor := event_source.call("entity", int(payload.get("actor_id", 0))) as CombatActor
	if actor == null or actor.actor_presentation == null:
		return
	actor.flash_remaining = 0.28
	actor.actor_presentation.spawn_concentration_rings(0.9, 0.45, "RespawnArrival")


func _packet_vector(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _resolve_effect_ability(source: CombatActor, payload: Dictionary) -> AbilityDefinition:
	var ability_id := str(payload.get("ability_id", ""))
	var expected_vfx := str(payload.get("ability_vfx_id", ""))
	var current := source.ability_by_id(ability_id)
	if current != null and (expected_vfx.is_empty() or current.vfx_id == expected_vfx):
		return current
	for candidate in source.definition.abilities:
		if candidate != null and candidate.ability_id == ability_id and (expected_vfx.is_empty() or candidate.vfx_id == expected_vfx):
			return candidate
	for candidate in source.definition.transformed_abilities:
		if candidate != null and candidate.ability_id == ability_id and (expected_vfx.is_empty() or candidate.vfx_id == expected_vfx):
			return candidate
	for value in source.definition.ability_variants.values():
		var candidate := value as AbilityDefinition
		if candidate != null and candidate.ability_id == ability_id and (expected_vfx.is_empty() or candidate.vfx_id == expected_vfx):
			return candidate
	return null


func _clear_entity_visuals() -> void:
	for visual_value in entity_visuals.values():
		var visual := visual_value as Node
		if visual != null and is_instance_valid(visual):
			visual.queue_free()
	entity_visuals.clear()


func _disconnect_source() -> void:
	if event_source == null or not is_instance_valid(event_source):
		return
	if event_source.has_signal("authoritative_event_emitted") and event_source.is_connected("authoritative_event_emitted", _consume_event):
		event_source.disconnect("authoritative_event_emitted", _consume_event)
	if event_source.has_signal("entity_replica_created") and event_source.is_connected("entity_replica_created", _on_entity_replica_created):
		event_source.disconnect("entity_replica_created", _on_entity_replica_created)
	if event_source.has_signal("entity_replica_removed") and event_source.is_connected("entity_replica_removed", _remove_entity_visual):
		event_source.disconnect("entity_replica_removed", _remove_entity_visual)
