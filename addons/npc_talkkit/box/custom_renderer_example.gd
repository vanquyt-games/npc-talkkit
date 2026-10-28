@tool
extends TalkBoxRenderer

@onready var _panel: PanelContainer = %Panel
@onready var _text: RichTextLabel = %DialogueText
@onready var _name: Label = %SpeakerName


func get_text_label() -> RichTextLabel:
	return _text


func get_name_label() -> Label:
	return _name



## Required for anchoring and transitions: returns the control that represents
## the box itself.
func get_box_control() -> Control:
	return _panel
