class_name HeroVisualLayerDefinition
extends Resource

@export var layer_id := "layer"
@export var texture: Texture2D
@export var pixel_size := 0.0092
# X is mirrored with left/right facing; Y is height above the actor origin.
@export var offset := Vector2.ZERO
@export var texture_offset := Vector2.ZERO
@export var base_rotation := 0.0
@export var remove_light_neutral_background := false
@export var render_priority := 0
@export var visible_by_default := true
@export var show_during_actions: PackedStringArray = []
@export var hide_during_actions: PackedStringArray = []
