## One speaker as a renderer should draw them: name and visual already resolved
## by [NPCTalkKit]. Built at runtime; not authored.
class_name TalkRenderParticipant
extends RefCounted

## The speaker, or null for a narrator line.
var speaker: TalkSpeaker
## The name to show, with [member TalkLine.display_name_override] applied.
var display_name := ""
## The visual for the line's variant, or null.
var visual: TalkDialogueVisual
## Whether this is the speaker of the line being shown.
var active := false


func _init(
	for_speaker: TalkSpeaker = null,
	name_shown := "",
	dialogue_visual: TalkDialogueVisual = null,
	is_active := false,
) -> void:
	speaker = for_speaker
	display_name = name_shown
	visual = dialogue_visual
	active = is_active
