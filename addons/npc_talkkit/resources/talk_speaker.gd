@tool
## A dialogue identity: name, visual inside the box, and voice.
##
## A speaker is not tied to a node in the scene, so a narrator, a radio voice or
## a sign works the same as a character. To animate the world character while it
## talks, do it from game code:
##
## [codeblock]
## $NPCTalkKit.play(&"greeting")
## $AnimationPlayer.play("talk")
## [/codeblock]
@icon("res://addons/npc_talkkit/icons/talk_speaker.svg")
class_name TalkSpeaker
extends Resource

@export_category("Identity")
## Stable key, used by [TalkKitDatabase] libraries and JSON content.
@export var speaker_id: StringName = &""
## Shown in the box's name row. Empty hides the row.
@export var display_name := ""

@export_category("Dialogue Visual")
## How this speaker is drawn inside the box. Empty draws nothing.
@export var visual: TalkDialogueVisual
## Named alternative visuals, such as "angry". Picked by
## [member TalkLine.visual_variant]; an unknown name falls back to
## [member visual].
@export var variants: Dictionary[StringName, TalkDialogueVisual] = {}

@export_category("Voice")
## Whether the voice blip plays for this speaker.
@export var voice_enabled := true
## Short blip played per character while the box types.
@export var voice_blip: AudioStream
@export_range(0.25, 4.0, 0.01) var voice_pitch_min := 0.95
@export_range(0.25, 4.0, 0.01) var voice_pitch_max := 1.05
@export_range(0.0, 1.0, 0.005) var voice_blip_interval := 0.04


func normalized_pitch_range() -> Vector2:
	return Vector2(minf(voice_pitch_min, voice_pitch_max), maxf(voice_pitch_min, voice_pitch_max))


## The visual for [param variant], or [member visual] when the variant is empty
## or unknown.
func resolve_visual(variant: StringName = &"") -> TalkDialogueVisual:
	if not variant.is_empty():
		var named: TalkDialogueVisual = variants.get(variant)
		if named != null:
			return named
	return visual
