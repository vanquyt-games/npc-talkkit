@tool
@icon("res://addons/npc_talkkit/icons/talk_line.svg")
class_name TalkLine
extends Resource

## One line of dialogue, plus any exceptions to its conversation's defaults.
##
## A line stores only what differs from the conversation: speaker, box,
## placement, event. Empty fields inherit.
##
## [member text] is BBCode rich text; the typewriter reveals characters, not
## tags.

## Who speaks this line: inherited, nobody, or [member speaker].
enum SpeakerMode {
	INHERIT,  ## Use the conversation's default speaker.
	NONE,     ## Nobody speaks this line — narrator, sign, system message.
	SPEAKER,  ## Use [member speaker].
}

@export_multiline var text := ""

@export_group("Overrides")
@export var speaker_mode: SpeakerMode = SpeakerMode.INHERIT
## Who says this line when [member speaker_mode] is SPEAKER. Usually one of the
## speakers on the NPCTalkKit node.
@export var speaker: TalkSpeaker
## A different dialogue box for this line. Empty uses the conversation's.
@export var dialogue_box: TalkBoxTemplate
## A different placement for this line. Empty uses the conversation's.
@export var placement: TalkAnchor

@export_group("Event")
## When set, emits event_triggered (or event_blocked) as the line finishes.
@export var event_id: StringName = &""
@export var event_payload: Variant
## Pause playback after this line and wait for the host to respond.
@export var event_blocking := false

@export_group("Advanced")
## Optional stable id for [method TalkConversation.get_line_by_id] and host code.
@export var line_id: StringName = &""
## Names a speaker by id, for content imported from JSON. Only read when
## [member speaker_mode] is SPEAKER and [member speaker] is empty.
@export var speaker_id: StringName = &""
## A different name for this line only, such as "???". The visual and voice
## stay the speaker's.
@export var display_name_override := ""
## One of the speaker's named visuals, such as "angry". An unknown name falls
## back to the default visual.
@export var visual_variant: StringName = &""
## Typewriter speed for this line only. Zero inherits from the box.
@export_range(0.0, 240.0, 1.0) var characters_per_second := 0.0
@export var voice_clip: AudioStream


# Shows the speaker fields only when speaker_mode is SPEAKER.
func _validate_property(property: Dictionary) -> void:
	if property.name in ["speaker", "speaker_id"] and speaker_mode != SpeakerMode.SPEAKER:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## A shallow copy used for {{param}} substitution, so a shared line is never
## modified. Referenced resources (speaker, box, voice clip) are not cloned, so
## identity checks such as [code]line.speaker == guard[/code] keep working.
func duplicate_line() -> TalkLine:
	return duplicate(false) as TalkLine


## True when the speaker is inherited from the conversation.
func inherits_speaker() -> bool:
	return speaker_mode == SpeakerMode.INHERIT
