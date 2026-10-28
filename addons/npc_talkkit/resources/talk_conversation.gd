@tool
@icon("res://addons/npc_talkkit/icons/talk_conversation.svg")
class_name TalkConversation
extends Resource

## A named, linear sequence of lines and the defaults those lines inherit.
##
## Lines play in order; branching is done by the host game through blocking
## events. A conversation may involve several speakers.

@export var conversation_id: StringName = &""

@export_group("Defaults")
## Speaker for lines that inherit. Empty means nobody (narration).
@export var default_speaker: TalkSpeaker
## Dialogue box for lines that do not override it.
@export var default_dialogue_box: TalkBoxTemplate
## Placement for lines that do not override it. Empty uses the renderer's own.
@export var default_placement: TalkAnchor

@export var lines: Array[TalkLine] = []

@export_group("Advanced")
## Emitted when the conversation completes. Always non-blocking.
@export var event_id: StringName = &""
@export var event_payload: Variant


func is_empty() -> bool:
	return lines.is_empty()


func get_line_by_id(line_id: StringName) -> TalkLine:
	for line in lines:
		if line != null and line.line_id == line_id:
			return line
	return null


## Every speaker used by this conversation, in order of first appearance.
## Inheriting lines count as [member default_speaker].
func speakers() -> Array[TalkSpeaker]:
	var found: Array[TalkSpeaker] = []
	for line in lines:
		if line == null:
			continue
		var speaker: TalkSpeaker = null
		match line.speaker_mode:
			TalkLine.SpeakerMode.INHERIT:
				speaker = default_speaker
			TalkLine.SpeakerMode.SPEAKER:
				speaker = line.speaker
		if speaker != null and not found.has(speaker):
			found.append(speaker)
	return found
