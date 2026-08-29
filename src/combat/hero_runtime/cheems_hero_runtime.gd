class_name CheemsHeroRuntime
extends HeroRuntime

## Cheems-specific combo and conditional ultimate rules. Damage pulses, energy,
## cooldowns and hit resolution stay in the shared combat runtimes.

func commit_ability(ability_id: String, _ability: AbilityDefinition, _bypass_cost: bool) -> void:
	if ability_id != "basic":
		actor.current_attack_damage_multiplier = 1.0
		return
	if actor.weapon_drawn:
		actor.basic_combo_step = (actor.basic_combo_step + 1) % 3
		actor.current_attack_damage_multiplier = 1.0
	else:
		actor.basic_combo_step = 0
		actor.current_attack_damage_multiplier = 1.5
		actor.weapon_drawn = true
		actor.sheathe_remaining = 0.0


func before_shared_activation(ability: AbilityDefinition, _attack_id: int) -> bool:
	if ability.vfx_id == "multi_slash":
		if not emit_hero_effect("cheems_multi_slash", {
			"ability_id": ability.ability_id,
			"duration": ability.active,
		}):
			var multi_vfx := _vfx()
			if multi_vfx != null:
				multi_vfx.start_horizontal_slashes(ability, ability.active)
		return true
	if ability.vfx_id != "dimensional_slash":
		return true
	if _has_enemy_in_radius(ability.hitbox_radius):
		return true
	actor.ability_phase = "recovery"
	actor.phase_remaining = 0.08
	if not emit_hero_effect("cheems_dimensional_cancel", {"duration": 0.06}):
		var vfx := _vfx()
		if vfx != null:
			vfx.dismiss_magic_circle(0.06)
	return false


func before_startup_effects(ability: AbilityDefinition) -> void:
	if ability.vfx_id == "dimensional_slash":
		if not emit_hero_effect("cheems_dimensional_focus", {
			"ability_id": ability.ability_id,
			"radius": ability.hitbox_radius,
			"duration": ability.startup,
		}):
			actor.actor_presentation.spawn_concentration_rings(ability.hitbox_radius, ability.startup, "CheemsUltimateFocus")


func after_startup_effects(ability: AbilityDefinition) -> void:
	if ability.vfx_id == "dimensional_slash":
		if not emit_hero_effect("cheems_dimensional_circle", {
			"ability_id": ability.ability_id,
			"duration": ability.startup + ability.active,
		}):
			var vfx := _vfx()
			if vfx != null:
				vfx.spawn_magic_circle(ability, ability.startup + ability.active)


func update_continuous_ability(delta: float) -> bool:
	if actor.current_ability == null or actor.current_ability.vfx_id != "multi_slash":
		return false
	return true


func on_hitbox_pulse(ability: AbilityDefinition, pulse_index: int) -> void:
	if ability.vfx_id != "dimensional_slash":
		return
	if not emit_hero_effect("cheems_dimensional_cut", {
		"ability_id": ability.ability_id,
		"pulse_index": pulse_index,
	}):
		var vfx := _vfx()
		if vfx != null:
			vfx.spawn_dimensional_cut(ability, pulse_index)


func on_basic_finished(cooldown: float) -> void:
	actor.sheathe_remaining = cooldown * 0.5


func advance(delta: float) -> void:
	if actor.current_ability != null or actor.sheathe_remaining <= 0.0:
		return
	actor.sheathe_remaining = maxf(0.0, actor.sheathe_remaining - delta)
	if actor.sheathe_remaining <= 0.0:
		actor.weapon_drawn = false
		actor.basic_combo_step = 0


func reset() -> void:
	actor.basic_combo_step = 0
	actor.weapon_drawn = false
	actor.sheathe_remaining = 0.0
	actor.current_attack_damage_multiplier = 1.0


func runtime_snapshot() -> Dictionary:
	return {
		"combo_step": actor.basic_combo_step,
		"weapon_drawn": actor.weapon_drawn,
		"sheathe_remaining": roundi(actor.sheathe_remaining * 10000.0),
		"damage_multiplier": roundi(actor.current_attack_damage_multiplier * 10000.0),
	}


func apply_runtime_snapshot(snapshot: Dictionary) -> void:
	actor.basic_combo_step = clampi(int(snapshot.get("combo_step", actor.basic_combo_step)), 0, 2)
	actor.weapon_drawn = bool(snapshot.get("weapon_drawn", actor.weapon_drawn))
	actor.sheathe_remaining = maxf(0.0, float(snapshot.get("sheathe_remaining", roundi(actor.sheathe_remaining * 10000.0))) / 10000.0)
	actor.current_attack_damage_multiplier = maxf(0.0, float(snapshot.get("damage_multiplier", roundi(actor.current_attack_damage_multiplier * 10000.0))) / 10000.0)


func _has_enemy_in_radius(radius: float) -> bool:
	for value in actor.get_tree().get_nodes_in_group("combat_actors"):
		if value is CombatActor:
			var candidate := value as CombatActor
			if candidate != actor and candidate.team != actor.team and not candidate.is_defeated and actor.global_position.distance_squared_to(candidate.global_position) <= radius * radius:
				return true
	return false


func _vfx() -> CheemsVfx:
	return actor.actor_presentation.hero_vfx as CheemsVfx
