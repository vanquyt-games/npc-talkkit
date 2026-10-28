@tool
## Small drag source/target used by dialogue rows. The panel owns the mutation;
## this control only reports which row was dropped onto which row.
extends Button

signal line_dropped(from_index: int, to_index: int)

var line_index := -1


func _ready() -> void:
	text = "≡"
	flat = true
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Drag to reorder · Alt+Up/Down also works"


func _get_drag_data(_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = "Move line %d" % (line_index + 1)
	set_drag_preview(preview)
	return {"talkkit_line_index": line_index}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("talkkit_line_index") \
		and int(data["talkkit_line_index"]) != line_index


func _drop_data(_position: Vector2, data: Variant) -> void:
	line_dropped.emit(int(data["talkkit_line_index"]), line_index)
