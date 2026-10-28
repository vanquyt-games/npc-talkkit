## Everything a renderer needs to draw one line, already resolved by
## [NPCTalkKit]. Renderers read these values rather than resolving their own.
class_name TalkContext
extends RefCounted

var component: NPCTalkKit
## The node a following anchor tracks. Used only as a position.
var target: Node
var conversation: TalkConversation
## The placement for this line. Null uses the renderer's default anchor.
var anchor: TalkAnchor
## The dialogue box this line resolved to.
var template: TalkBoxTemplate
## Characters per second. Zero shows each line at once.
var typewriter_speed := 40.0

## The speaker of this line, ready to draw. Null for a narrator.
var active: TalkRenderParticipant
## Everyone the box should keep on screen, including [member active]. The
## built-in boxes draw only [member active], so this holds at most one entry; a
## custom renderer may draw more.
var visible: Array[TalkRenderParticipant] = []


func _init(
	owner_component: NPCTalkKit = null,
	owner_target: Node = null,
	active_conversation: TalkConversation = null,
	placement: TalkAnchor = null,
	box_template: TalkBoxTemplate = null,
	speed := 40.0,
	active_participant: TalkRenderParticipant = null,
	visible_participants: Array[TalkRenderParticipant] = [],
) -> void:
	component = owner_component
	target = owner_target
	conversation = active_conversation
	anchor = placement
	template = box_template
	typewriter_speed = speed
	active = active_participant
	visible = visible_participants


## The speaker name to put in the box's name row, or "" to hide it.
func display_name() -> String:
	return active.display_name if active != null else ""


## The image to draw [param elapsed] seconds into the line, or null for none.
func visual_texture(elapsed := 0.0) -> Texture2D:
	if active == null or active.visual == null:
		return null
	return active.visual.frame_texture(elapsed)


## The speaker whose voice blips play while the box types, or null for silence.
func voice_speaker() -> TalkSpeaker:
	if active == null or active.speaker == null:
		return null
	return active.speaker if active.speaker.voice_enabled else null
