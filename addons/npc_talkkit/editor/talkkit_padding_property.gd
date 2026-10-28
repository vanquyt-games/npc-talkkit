@tool
## The one Padding row of a box: the Panel, a name box or a frame. A nine-slice
## or StyleBox resource picks between its own margins, shown read-only, and
## Custom values typed in place. Other sources have no margins of their own,
## so they show the values only.
extends EditorProperty

const SIDES := ["L", "T", "R", "B"]

var _option: OptionButton
var _note: Label
var _fields: HBoxContainer
var _spins: Array[EditorSpinSlider] = []
var _updating := false


func _init() -> void:
	var body := VBoxContainer.new()
	_option = OptionButton.new()
	_option.add_item("Style margins", TalkBoxLayer.PaddingMode.STYLE_MARGINS)
	_option.add_item("Custom padding", TalkBoxLayer.PaddingMode.CUSTOM)
	_option.item_selected.connect(_on_selected)
	body.add_child(_option)
	_fields = HBoxContainer.new()
	_fields.add_theme_constant_override("separation", 2)
	for index in SIDES.size():
		# The same field Godot uses for a Vector4, so the row lines up with its
		# neighbours.
		var spin := EditorSpinSlider.new()
		spin.label = SIDES[index]
		spin.min_value = 0
		spin.max_value = 512
		spin.step = 1
		spin.allow_greater = true
		spin.hide_slider = true
		spin.custom_minimum_size.x = 40
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_on_value_changed)
		_fields.add_child(spin)
		_spins.append(spin)
	body.add_child(_fields)
	_note = Label.new()
	_note.clip_text = true
	_note.modulate.a = 0.7
	_note.add_theme_font_size_override("font_size", 11)
	body.add_child(_note)
	add_child(body)
	add_focusable(_option)


func _update_property() -> void:
	var info := _info()
	if info.is_empty():
		return
	_updating = true
	var flat: bool = info["custom_only"]
	_option.visible = not flat
	_option.select(info["mode"])
	_fields.visible = flat or info["mode"] == TalkBoxLayer.PaddingMode.CUSTOM
	var values: Vector4 = info["padding"]
	for index in 4:
		_spins[index].value = values[index]
	_updating = false
	_note.text = summary(info)
	_note.tooltip_text = describe(info)
	_note.visible = not flat


# The edited object answers for the row this editor sits in: the Panel, a
# layer, or a single name box or frame shown in the box's settings.
func _info() -> Dictionary:
	var object := get_edited_object()
	if object == null or not object.has_method("padding_info"):
		return {}
	return object.call("padding_info", _prefix())


func _prefix() -> String:
	return String(get_edited_property()).trim_suffix("padding_mode")


## What padding applies, in words, from a padding_info() dictionary.
static func describe(info: Dictionary) -> String:
	if info["custom_only"]:
		return "Left, top, right, bottom."
	var margins: Vector4 = info["style_margins"]
	var values := "%d · %d · %d · %d px" % [roundi(margins.x), roundi(margins.y), roundi(margins.z), roundi(margins.w)]
	if info["mode"] == TalkBoxLayer.PaddingMode.STYLE_MARGINS:
		return "From the style: %s (left, top, right, bottom). Read-only." % values
	return "Overrides the style's margins (%s)." % values


## The compact, single-line form used in the workspace.
static func summary(info: Dictionary) -> String:
	if info["custom_only"]:
		return "L · T · R · B"
	var margins: Vector4 = info["style_margins"]
	var values := "%d · %d · %d · %d px" % [roundi(margins.x), roundi(margins.y), roundi(margins.z), roundi(margins.w)]
	return ("Style: " if info["mode"] == TalkBoxLayer.PaddingMode.STYLE_MARGINS else "Style was: ") + values


func _on_selected(index: int) -> void:
	if not _updating:
		emit_changed(get_edited_property(), _option.get_item_id(index))


func _on_value_changed(_value: float) -> void:
	if not _updating:
		emit_changed(StringName(_prefix() + "padding"), Vector4(_spins[0].value, _spins[1].value, _spins[2].value, _spins[3].value))
