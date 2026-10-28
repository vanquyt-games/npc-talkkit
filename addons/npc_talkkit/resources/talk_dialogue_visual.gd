@tool
## How a speaker looks inside the dialogue box: a still texture or an animated
## [SpriteFrames].
##
## It reads assets, not scene nodes. Reuse the game's own [SpriteFrames] to give
## a character the same look in the box:
##
## [codeblock]
## World Player                TalkSpeaker "Player"
## └─ AnimatedSprite2D         └─ visual
##    └─ player_frames.tres       └─ sprite_frames = player_frames.tres
## [/codeblock]
@icon("res://addons/npc_talkkit/icons/talk_dialogue_visual.svg")
class_name TalkDialogueVisual
extends Resource

## A still image, such as a portrait.
@export var texture: Texture2D

@export_group("Animated")
## An animated visual. Ignored while [member texture] is set.
@export var sprite_frames: SpriteFrames
@export var animation: StringName = &"default"

@export_group("Advanced")
## Mirrors the visual horizontally.
@export var flip_h := false


func is_empty() -> bool:
	return texture == null and sprite_frames == null


## The image to draw [param elapsed] seconds after this visual appeared.
## Animated visuals are sampled from [member sprite_frames] by elapsed time,
## honouring the animation's speed and loop setting.
func frame_texture(elapsed := 0.0) -> Texture2D:
	if texture != null:
		return texture
	if sprite_frames == null or not sprite_frames.has_animation(animation):
		return null
	var count := sprite_frames.get_frame_count(animation)
	if count <= 0:
		return null
	var speed := sprite_frames.get_animation_speed(animation)
	if speed <= 0.0:
		return sprite_frames.get_frame_texture(animation, 0)
	var index := int(elapsed * speed)
	if sprite_frames.get_animation_loop(animation):
		index = posmod(index, count)
	else:
		index = mini(index, count - 1)
	return sprite_frames.get_frame_texture(animation, index)
