class_name AbilityDefinition
extends Resource

@export var ability_id := "ability"
@export var display_name := "Ability"
@export var startup := 0.12
@export var active := 0.10
@export var recovery := 0.22
@export var cooldown := 0.45
@export var stamina_cost := 0.0
@export var energy_cost := 0.0
@export var damage := 10.0
@export var knockback := 0.0
# Local 3D volume: X width, Y height, Z forward depth. Local forward is -Z.
@export var hitbox_size := Vector3(1.25, 1.15, 0.9)
@export var hitbox_distance := 0.72
@export var hitbox_center_y := 0.68
@export var projectile_speed := 0.0
@export var projectile_lifetime := 1.8
@export var projectile_radius := 0.18
@export var projectile_height := 0.92
@export var projectile_deceleration := 0.0
@export var projectile_homing := false
@export var energy_on_hit := 8.0
@export var healing_on_hit := 0.0
@export var lifesteal_ratio := 0.0
@export var movement_impulse := 0.0
@export var color := Color("f5c451")
# Reusable combat semantics. Presentation and targeting remain data-driven.
@export_enum("box", "arc", "circle") var hitbox_shape := "box"
@export var hitbox_radius := 1.0
@export var arc_degrees := 180.0
@export var active_duration_override := 0.0
@export var hit_interval := 0.0
@export var max_hits_per_target := 1
@export var projectile_destroyer := false
@export var projectile_pierces_actors := false
@export var refresh_cooldown_on_hit := false
@export var cancelable_by_movement := false
@export var cancelable_by_ability := false
@export var locks_movement := false
@export var dash_distance := 0.0
@export var endpoint_phase_dash := false
@export var apply_slow_ratio := 1.0
@export var apply_slow_duration := 0.0
@export var apply_root_duration := 0.0
@export var apply_stun_duration := 0.0
@export var apply_stun_delay := 0.0
@export var knockup_speed := 0.0
@export var knockup_control_duration := 0.0
@export var startup_slow_ratio := 1.0
@export var startup_slow_duration := 0.0
@export var self_control_immune_duration := 0.0
@export var self_untargetable_duration := 0.0
@export var execute_missing_hp_ratio := 0.0
@export var vfx_id := ""
@export var auto_target_radius := 0.0
@export var requires_aim_confirmation := true
@export var spawns_attack := true
@export var disabled := false
# Hold abilities stay active until an END_ABILITY command arrives. Cooldown starts on end.
@export var hold_to_channel := false
@export var minimum_hold_duration := 0.0
@export var maximum_hold_duration := 0.0
@export var move_speed_multiplier_during_cast := 0.22
@export var face_movement_during_cast := false
@export var damage_taken_multiplier_during_cast := 1.0
@export var uninterruptible_by_damage := false
@export var blocks_front_damage := false
@export var front_block_degrees := 120.0
@export var pulse_damage: PackedFloat32Array = []
# Optional world-anchored follow-up. Its center is snapshotted when the ability
# becomes active, so delayed ground attacks never follow their caster.
@export var delayed_damage := 0.0
@export var delayed_delay := 0.0
@export var delayed_radius := 0.0
@export var delayed_center_distance := 0.0
@export var delayed_center_y := 0.70
@export var cooldown_on_finish := false
@export var cooldown_on_form_end := false
@export var breaks_stealth := true
@export var target_required_range := 0.0
@export var target_delayed_damage_delay := 0.0
@export var target_delayed_missing_hp_ratio := 0.0


func total_duration() -> float:
	return startup + active + recovery


func is_projectile() -> bool:
	return projectile_speed > 0.0
