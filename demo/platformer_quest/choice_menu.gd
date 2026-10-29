extends PanelContainer
## The game's own choice menu. TalkKit draws no buttons: a blocking event pauses
## the conversation, and the game asks the player with whatever UI it already has.

signal _picked(index: int)

@onready var _list: VBoxContainer = $List


func _ready() -> void:
	hide()


## Shows one button per option and waits. Returns the chosen index, or -1 if
## the menu was closed with cancel().
func ask(options: Array) -> int:
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	for index in options.size():
		var button := Button.new()
		button.text = str(options[index])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_picked.emit.bind(index))
		_list.add_child(button)
	show()
	(_list.get_child(0) as Button).grab_focus()
	var index: int = await _picked
	hide()
	return index


func cancel() -> void:
	if visible:
		_picked.emit(-1)
