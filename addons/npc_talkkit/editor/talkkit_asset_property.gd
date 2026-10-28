@tool
## A compact asset picker for Dialogue Box appearance resources. Unlike
## Godot's default Resource editor, it never unfolds the selected texture or
## StyleBox inside the already narrow TalkKit workspace.
extends EditorProperty

var _base_type := "Resource"
var _picker: EditorResourcePicker
var _updating := false


func setup(base_type: String) -> void:
	_base_type = base_type
	_picker = EditorResourcePicker.new()
	_picker.base_type = _base_type
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.tooltip_text = "Drag, load or quick-create an asset"
	_picker.resource_changed.connect(_on_resource_changed)
	add_child(_picker)
	add_focusable(_picker)


func _update_property() -> void:
	if _picker == null:
		return
	_updating = true
	_picker.edited_resource = get_edited_object().get(get_edited_property())
	_updating = false


func _on_resource_changed(value: Resource) -> void:
	if not _updating:
		emit_changed(get_edited_property(), value)
