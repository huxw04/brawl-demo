class_name HeroDefinition
extends Resource

@export var hero_id := "hero"
@export var display_name := "Hero"
@export var theme_color := Color("62c5da")
@export var max_hp := 140.0
@export var move_speed := 2.55
@export var max_stamina := 100.0
@export var stamina_regen := 26.0
@export var stamina_regen_delay := 0.65
@export var max_energy := 100.0
@export var starts_with_full_energy := false
@export var status_bar_id := "energy"
@export var status_bar_label := "ENERGY"
@export var status_bar_color := Color("b66cff")
@export var jump_cost := 0.0
@export var roll_cost := 33.3333
@export var body_radius := 0.34
@export var body_height := 1.72
@export var jump_speed := 6.6
@export var gravity := 18.0
@export var sprite_texture: Texture2D
@export var sprite_pixel_size := 0.0092
@export var sprite_y := 0.88
@export var sprite_faces_right := true
@export var movement_sprite_textures: Array[Texture2D] = []
@export var movement_sprite_frame_durations := PackedFloat32Array()
var action_sprite_textures: Dictionary = {}
var ability_variants: Dictionary = {}
@export var visual_layers: Array[HeroVisualLayerDefinition] = []
@export var abilities: Array[AbilityDefinition] = []
@export var transformed_sprite_texture: Texture2D
@export var transformed_sprite_pixel_size := 0.0
@export var transform_duration := 0.0
@export var transformed_move_speed_multiplier := 1.0
@export var transformed_abilities: Array[AbilityDefinition] = []
var sprite_pose_clips: Dictionary = {}


func ability_by_id(id: String) -> AbilityDefinition:
	for ability in abilities:
		if ability.ability_id == id:
			return ability
	return null


func transformed_ability_by_id(id: String) -> AbilityDefinition:
	for ability in transformed_abilities:
		if ability.ability_id == id:
			return ability
	return null
