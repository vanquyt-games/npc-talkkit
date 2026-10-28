## Optional proximity trigger: starts a conversation on an [NPCTalkKit] when a
## body from [member accepted_body_group] is inside and [member input_action] is
## pressed. The 3D counterpart of [TalkInteractionArea2D].
##
## Optional: calling [method NPCTalkKit.play] from your own interaction code
## works just as well.
@icon("res://addons/npc_talkkit/icons/talk_interaction_area_3d.svg")
class_name TalkInteractionArea3D
extends Area3D

signal availability_changed(available: bool)

@export var talkkit_component: NPCTalkKit
@export var conversation_id: StringName
@export var input_action: StringName = &"ui_accept"
@export var accepted_body_group: StringName = &"player"

var _available_bodies: Array[Node3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _available_bodies.is_empty() and event.is_action_pressed(input_action):
		if talkkit_component != null:
			talkkit_component.play(conversation_id)
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node3D) -> void:
	if accepted_body_group.is_empty() or body.is_in_group(accepted_body_group):
		_available_bodies.append(body)
		availability_changed.emit(true)


func _on_body_exited(body: Node3D) -> void:
	_available_bodies.erase(body)
	availability_changed.emit(not _available_bodies.is_empty())
