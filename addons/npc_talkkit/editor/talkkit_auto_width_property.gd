@tool
## A width where 0 means "follow the size": an Auto toggle, and the width once
## it is turned off. Turning Auto off starts from the width Auto was drawing.
extends EditorProperty

var _auto: CheckBox
var _spin: EditorSpinSlider
var _updating := false


func _init() -> void:
	var row := HBoxContainer.new()
	_auto = CheckBox.new()
	_auto.text = "Auto"
	_auto.tooltip_text = "Follow Tail Size."
	_auto.toggled.connect(_on_auto_toggled)
	row.add_child(_auto)
	_spin = EditorSpinSlider.new()
	_spin.min_value = 1
	_spin.max_value = 96
	_spin.step = 1
	_spin.allow_greater = true
	_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin.value_changed.connect(_on_value_changed)
	row.add_child(_spin)
	add_child(row)
	add_focusable(_auto)
	add_focusable(_spin)


func _update_property() -> void:
	var template := get_edited_object() as TalkBoxTemplate
	if template == null:
		return
	_updating = true
	var width: float = template.get(get_edited_property())
	_auto.button_pressed = width <= 0.0
	_spin.value = width if width > 0.0 else template.tail_half_width() * 2.0
	_spin.read_only = width <= 0.0
	_updating = false


func _on_auto_toggled(on: bool) -> void:
	if _updating:
		return
	emit_changed(get_edited_property(), 0.0 if on else roundf(_spin.value))


func _on_value_changed(value: float) -> void:
	if _updating or _auto.button_pressed:
		return
	emit_changed(get_edited_property(), value)
