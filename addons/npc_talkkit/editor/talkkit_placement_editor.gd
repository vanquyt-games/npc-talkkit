@tool
## Editor for a TalkAnchor that shows only the controls for its current mode.
extends VBoxContainer

signal replacement_requested(anchor: TalkAnchor)
signal changed

var anchor: TalkAnchor
var editor_plugin: EditorPlugin
var _updating := false
var _empty: Button
var _body: VBoxContainer
var _mode: OptionButton
var _visual: Control
var _screen: VBoxContainer
var _follow: VBoxContainer
var _advanced: VBoxContainer
var _spots: Array[Button] = []
var _margin_x: SpinBox
var _margin_y: SpinBox
var _stretch: CheckBox
var _size_x: SpinBox
var _size_y: SpinBox
var _target: LineEdit
var _offset_x: SpinBox
var _offset_y: SpinBox
var _pivot_x: SpinBox
var _pivot_y: SpinBox
var _offscreen: OptionButton
var _viewport_margin: SpinBox
var _head: Array[SpinBox] = []
var _distance: SpinBox
var _scale_distance: CheckBox
var _occluded: CheckBox


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_empty = Button.new()
	_empty.text = "Customize placement"
	_empty.tooltip_text = "Create a placement override"
	_empty.pressed.connect(func() -> void: replacement_requested.emit(TalkAnchor.new()))
	add_child(_empty)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	add_child(_body)
	_mode = OptionButton.new()
	_mode.add_item("Screen", TalkAnchor.Mode.SCREEN)
	_mode.add_item("Follow node", TalkAnchor.Mode.NODE_FOLLOW)
	_mode.item_selected.connect(_set_mode)
	_body.add_child(_mode)

	_visual = Control.new()
	# No horizontal minimum: in the narrow detail drawer the text must keep room.
	_visual.custom_minimum_size = Vector2(0, 108)
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.tooltip_text = "Placement preview"
	_visual.draw.connect(_draw_visual_preview)
	_body.add_child(_visual)

	_screen = VBoxContainer.new()
	_screen.add_theme_constant_override("separation", 4)
	_body.add_child(_screen)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_screen.add_child(grid)
	for spot in range(TalkAnchor.Spot.TOP_LEFT, TalkAnchor.Spot.BOTTOM_RIGHT + 1):
		var button := Button.new()
		button.text = ["↖", "↑", "↗", "←", "•", "→", "↙", "↓", "↘"][spot]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(34, 28)
		button.pressed.connect(_set_spot.bind(spot))
		grid.add_child(button)
		_spots.append(button)
	_margin_x = _number_row(_screen, "Horizontal margin", 0, 2048, 1, " px")
	_margin_y = _number_row(_screen, "Vertical margin", 0, 2048, 1, " px")
	_stretch = CheckBox.new()
	_stretch.text = "Stretch to viewport width"
	_stretch.toggled.connect(func(value: bool) -> void: _apply(&"stretch_horizontal", value))
	_screen.add_child(_stretch)
	_size_x = _number_row(_screen, "Box width · 0 is natural", 0, 4096, 1, " px")
	_size_y = _number_row(_screen, "Box height · 0 is natural", 0, 4096, 1, " px")
	_margin_x.value_changed.connect(func(value: float) -> void: _set_vector2(&"screen_margin", "x", value))
	_margin_y.value_changed.connect(func(value: float) -> void: _set_vector2(&"screen_margin", "y", value))
	_size_x.value_changed.connect(func(value: float) -> void: _set_vector2(&"box_size", "x", value))
	_size_y.value_changed.connect(func(value: float) -> void: _set_vector2(&"box_size", "y", value))

	_follow = VBoxContainer.new()
	_follow.add_theme_constant_override("separation", 4)
	_body.add_child(_follow)
	_target = _text_row(_follow, "Target node · empty follows conversation target")
	_target.text_submitted.connect(func(value: String) -> void: _apply(&"follow_target", NodePath(value)))
	_target.focus_exited.connect(func() -> void: _apply(&"follow_target", NodePath(_target.text)))
	_offset_x = _number_row(_follow, "Screen offset X", -4096, 4096, 1, " px")
	_offset_y = _number_row(_follow, "Screen offset Y", -4096, 4096, 1, " px")
	_pivot_x = _number_row(_follow, "Pivot X", 0, 1, 0.05, "")
	_pivot_y = _number_row(_follow, "Pivot Y", 0, 1, 0.05, "")
	_offset_x.value_changed.connect(func(value: float) -> void: _set_vector2(&"follow_offset", "x", value))
	_offset_y.value_changed.connect(func(value: float) -> void: _set_vector2(&"follow_offset", "y", value))
	_pivot_x.value_changed.connect(func(value: float) -> void: _set_vector2(&"pivot", "x", value))
	_pivot_y.value_changed.connect(func(value: float) -> void: _set_vector2(&"pivot", "y", value))
	_offscreen = OptionButton.new()
	_offscreen.add_item("Clamp inside viewport", TalkAnchor.Offscreen.CLAMP)
	_offscreen.add_item("Hide when offscreen", TalkAnchor.Offscreen.HIDE)
	_offscreen.add_item("Allow offscreen", TalkAnchor.Offscreen.FREE)
	_offscreen.item_selected.connect(func(index: int) -> void: _apply(&"when_offscreen", _offscreen.get_item_id(index)))
	_labeled(_follow, "When target is offscreen", _offscreen)
	_viewport_margin = _number_row(_follow, "Viewport margin", 0, 512, 1, " px")
	_viewport_margin.value_changed.connect(func(value: float) -> void: _apply(&"viewport_margin", value))

	var advanced_toggle := Button.new()
	advanced_toggle.text = "Advanced 3D ▸"
	advanced_toggle.flat = true
	advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body.add_child(advanced_toggle)
	_advanced = VBoxContainer.new()
	_advanced.visible = false
	_body.add_child(_advanced)
	advanced_toggle.pressed.connect(func() -> void:
		_advanced.visible = not _advanced.visible
		advanced_toggle.text = "Advanced 3D ▾" if _advanced.visible else "Advanced 3D ▸")
	for axis in ["x", "y", "z"]:
		var row := _number_row(_advanced, "Head offset %s" % axis.to_upper(), -1000, 1000, 0.05, " m")
		row.value_changed.connect(func(value: float) -> void: _set_head_offset(axis, value))
		_head.append(row)
	_distance = _number_row(_advanced, "Maximum distance · 0 is unlimited", 0, 10000, 0.5, " m")
	_distance.value_changed.connect(func(value: float) -> void: _apply(&"max_distance", value))
	_scale_distance = CheckBox.new()
	_scale_distance.text = "Scale with distance"
	_scale_distance.toggled.connect(func(value: bool) -> void: _apply(&"scale_with_distance", value))
	_advanced.add_child(_scale_distance)
	_occluded = CheckBox.new()
	_occluded.text = "Hide when occluded"
	_occluded.toggled.connect(func(value: bool) -> void: _apply(&"hide_when_occluded", value))
	_advanced.add_child(_occluded)
	refresh()


func edit_anchor(value: TalkAnchor) -> void:
	anchor = value
	if is_node_ready():
		refresh()


func refresh() -> void:
	if _empty == null:
		return
	_updating = true
	var has := anchor != null
	_empty.visible = not has
	_body.visible = has
	if not has:
		_updating = false
		return
	_mode.selected = _mode.get_item_index(anchor.mode)
	_screen.visible = anchor.mode == TalkAnchor.Mode.SCREEN
	_follow.visible = anchor.mode == TalkAnchor.Mode.NODE_FOLLOW
	for spot in _spots.size():
		_spots[spot].button_pressed = anchor.screen_spot == spot
	_margin_x.value = anchor.screen_margin.x
	_margin_y.value = anchor.screen_margin.y
	_stretch.button_pressed = anchor.stretch_horizontal
	_size_x.value = anchor.box_size.x
	_size_y.value = anchor.box_size.y
	_target.text = String(anchor.follow_target)
	_offset_x.value = anchor.follow_offset.x
	_offset_y.value = anchor.follow_offset.y
	_pivot_x.value = anchor.pivot.x
	_pivot_y.value = anchor.pivot.y
	_offscreen.selected = _offscreen.get_item_index(anchor.when_offscreen)
	_viewport_margin.value = anchor.viewport_margin
	for index in _head.size():
		_head[index].value = anchor.follow_offset_3d[index]
	_distance.value = anchor.max_distance
	_scale_distance.button_pressed = anchor.scale_with_distance
	_occluded.button_pressed = anchor.hide_when_occluded
	_updating = false
	_visual.queue_redraw()


func _set_mode(index: int) -> void:
	_apply(&"mode", _mode.get_item_id(index))
	refresh()


func _set_spot(spot: int) -> void:
	_apply(&"screen_spot", spot)
	refresh()


func _apply(property: StringName, value: Variant) -> void:
	if _updating or anchor == null or anchor.get(property) == value:
		return
	if Engine.is_editor_hint() and editor_plugin != null:
		var undo := editor_plugin.get_undo_redo()
		undo.create_action(
			"Change placement %s" % String(property).replace("_", " "),
			UndoRedo.MERGE_ENDS,
			anchor,
		)
		undo.add_do_property(anchor, property, value)
		undo.add_undo_property(anchor, property, anchor.get(property))
		undo.add_do_method(self, &"_after_apply")
		undo.add_undo_method(self, &"_after_apply")
		undo.commit_action()
		return
	anchor.set(property, value)
	_after_apply()


func _after_apply() -> void:
	if anchor == null:
		return
	anchor.emit_changed()
	changed.emit()
	refresh()


func _draw_visual_preview() -> void:
	if anchor == null or _visual == null:
		return
	var rect := Rect2(Vector2(8, 6), _visual.size - Vector2(16, 12))
	var background := Color(0.07, 0.08, 0.09, 0.95)
	var border := Color(0.42, 0.46, 0.52, 0.7)
	var accent := Color(0.30, 0.62, 1.0, 0.95)
	_visual.draw_rect(rect, background, true)
	_visual.draw_rect(rect, border, false, 1.0)
	if anchor.mode == TalkAnchor.Mode.SCREEN:
		var positions := [
			Vector2(0.16, 0.20), Vector2(0.50, 0.20), Vector2(0.84, 0.20),
			Vector2(0.16, 0.50), Vector2(0.50, 0.50), Vector2(0.84, 0.50),
			Vector2(0.16, 0.80), Vector2(0.50, 0.80), Vector2(0.84, 0.80),
		]
		var point: Vector2 = positions[clampi(anchor.screen_spot, 0, positions.size() - 1)]
		var center := rect.position + rect.size * point
		var width := rect.size.x * (0.76 if anchor.stretch_horizontal else 0.34)
		var box := Rect2(center - Vector2(width * 0.5, 13), Vector2(width, 26))
		_visual.draw_rect(box, Color(accent, 0.24), true)
		_visual.draw_rect(box, accent, false, 2.0)
	else:
		var target := rect.position + rect.size * Vector2(0.50, 0.48)
		var box_center := target + Vector2(anchor.follow_offset.x, anchor.follow_offset.y).limit_length(34.0)
		var box := Rect2(box_center + Vector2(-45, -34), Vector2(90, 24))
		_visual.draw_circle(target, 5.0, accent)
		_visual.draw_line(target, box.get_center(), Color(accent, 0.65), 1.5)
		_visual.draw_rect(box, Color(accent, 0.24), true)
		_visual.draw_rect(box, accent, false, 2.0)


## The 3D offset is in world space, applied before projection, so it stays on
## the character's head as the camera moves.
func _set_head_offset(axis: String, value: float) -> void:
	if _updating or anchor == null:
		return
	var offset := anchor.follow_offset_3d
	offset["xyz".find(axis)] = value
	_apply(&"follow_offset_3d", offset)


func _set_vector2(property: StringName, axis: String, value: float) -> void:
	if _updating or anchor == null:
		return
	var vector: Vector2 = anchor.get(property)
	vector.x = value if axis == "x" else vector.x
	vector.y = value if axis == "y" else vector.y
	_apply(property, vector)


func _number_row(parent: Control, title: String, minimum: float, maximum: float, step: float, suffix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.suffix = suffix
	_labeled(parent, title, spin)
	return spin


func _text_row(parent: Control, title: String) -> LineEdit:
	var edit := LineEdit.new()
	_labeled(parent, title, edit)
	return edit


func _labeled(parent: Control, title: String, control: Control) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 10)
	label.modulate.a = 0.7
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)
