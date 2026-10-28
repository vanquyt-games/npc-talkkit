@tool
## Edits nine-slice patch margins with the guides drawn on the image itself,
## so the corners being protected are visible while the numbers change.
extends EditorProperty

const SIDES := ["L", "T", "R", "B"]
const PREVIEW_SIZE := 76.0

var _image: Control
var _spins: Array[EditorSpinSlider] = []
var _updating := false


func _init() -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	_image = Control.new()
	_image.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	_image.tooltip_text = "Pink guides mark the source pixels that stay unstretched."
	_image.draw.connect(_draw_image)
	body.add_child(_image)
	var fields := HBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 2)
	for index in SIDES.size():
		var spin := EditorSpinSlider.new()
		spin.label = SIDES[index]
		spin.min_value = 0
		spin.max_value = 4096
		spin.step = 1
		spin.suffix = "px"
		spin.hide_slider = true
		spin.custom_minimum_size.x = 42
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_on_value_changed)
		fields.add_child(spin)
		_spins.append(spin)
	body.add_child(fields)
	add_child(body)
	set_bottom_editor(body)


func _update_property() -> void:
	var margins: Vector4 = get_edited_object().get(get_edited_property())
	_updating = true
	for index in 4:
		_spins[index].value = margins[index]
	_updating = false
	var object := get_edited_object()
	var prefix := String(get_edited_property()).trim_suffix("nine_slice_margins")
	var texture := object.get(prefix + "nine_slice_texture") as Texture2D if object != null else null
	_image.visible = texture != null
	_image.queue_redraw()


func _on_value_changed(_value: float) -> void:
	if _updating:
		return
	var margins := Vector4(_spins[0].value, _spins[1].value, _spins[2].value, _spins[3].value)
	emit_changed(get_edited_property(), margins)
	_image.queue_redraw()


func _draw_image() -> void:
	# The texture sits beside the margins, under the same prefix: the Panel's,
	# a layer's, or a name box's shown in the box's settings.
	var object := get_edited_object()
	var prefix := String(get_edited_property()).trim_suffix("nine_slice_margins")
	var texture := object.get(prefix + "nine_slice_texture") as Texture2D if object != null else null
	var area := Rect2(Vector2.ZERO, _image.size)
	_image.draw_rect(area, Color(0, 0, 0, 0.25), true)
	if texture == null:
		return
	var source := texture.get_size()
	var fit := minf(area.size.x / source.x, area.size.y / source.y)
	var drawn := Rect2((area.size - source * fit) * 0.5, source * fit)
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.draw_texture_rect(texture, drawn, false)
	var margins := Vector4(_spins[0].value, _spins[1].value, _spins[2].value, _spins[3].value) * fit
	var guide := Color(1.0, 0.37, 0.66)
	_image.draw_line(Vector2(drawn.position.x + margins.x, area.position.y), Vector2(drawn.position.x + margins.x, area.end.y), guide)
	_image.draw_line(Vector2(drawn.end.x - margins.z, area.position.y), Vector2(drawn.end.x - margins.z, area.end.y), guide)
	_image.draw_line(Vector2(area.position.x, drawn.position.y + margins.y), Vector2(area.end.x, drawn.position.y + margins.y), guide)
	_image.draw_line(Vector2(area.position.x, drawn.end.y - margins.w), Vector2(area.end.x, drawn.end.y - margins.w), guide)
