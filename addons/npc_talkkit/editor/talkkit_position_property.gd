@tool
## Edits a layer's Position with the same 3×3 picker as Add Layer.
extends EditorProperty

const PositionGrid := preload("res://addons/npc_talkkit/editor/talkkit_position_grid.gd")

var _grid: HBoxContainer


func _init() -> void:
	_grid = PositionGrid.new()
	_grid.position_chosen.connect(func(spot: TalkBoxLayer.Position) -> void:
		emit_changed(get_edited_property(), spot))
	add_child(_grid)


func _update_property() -> void:
	_grid.set_chosen(get_edited_object().get(get_edited_property()))
