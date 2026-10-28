@tool
## The built-in dialogue box renderer. It contains every part a box can draw;
## the [TalkBoxTemplate] decides which parts appear and how they look.
extends TalkBoxRenderer

@onready var _box: PanelContainer = %Box
@onready var _content: HBoxContainer = %Content
@onready var _copy: VBoxContainer = %Copy
@onready var _visual: TextureRect = %Visual
@onready var _name: Label = %SpeakerName
@onready var _text: RichTextLabel = %DialogueText
@onready var _continue: MarginContainer = %Continue
@onready var _continue_glyph: Label = %ContinueGlyph
@onready var _continue_image: TextureRect = %ContinueImage
@onready var _tail: Polygon2D = %Tail

# Holds the speaker's name while it sits on the Panel's top edge. Internal, so
# the Panel's layout ignores it, and drawn after the Panel's layers.
var _name_edge: Control
# True while the tail hangs from the top edge.
var _tail_up := false


func get_box_control() -> Control:
	return _box


func get_content_container() -> BoxContainer:
	return _content


func get_visual_rect() -> TextureRect:
	return _visual


func get_name_label() -> Label:
	return _name


func get_text_label() -> RichTextLabel:
	return _text


func get_continue_label() -> Label:
	return _continue_glyph


func get_continue_image() -> TextureRect:
	return _continue_image


func get_continue_indicator() -> Control:
	return _continue


func get_tail() -> Polygon2D:
	return _tail


func apply_template() -> void:
	super.apply_template()
	_place_name()


# Moves the name between its inline spot above the text and the top edge.
func _place_name() -> void:
	if effective_template().name_placement == TalkBoxTemplate.NamePlacement.TOP_EDGE:
		if _name_edge == null:
			_name_edge = Control.new()
			_name_edge.name = "NameEdge"
			_name_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_name_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
		if _name_edge.get_parent() == _box:
			_box.remove_child(_name_edge)
		# Last, so the name sits over the Panel's own layers.
		_box.add_child(_name_edge, false, Node.INTERNAL_MODE_BACK)
		if _name.get_parent() != _name_edge:
			_name.reparent(_name_edge, false)
		_layout_name_edge()
	elif _name.get_parent() != _copy:
		_name.reparent(_copy, false)
		_copy.move_child(_name, 0)


func _layout_name_edge() -> void:
	if _name_edge == null or _name.get_parent() != _name_edge:
		return
	var template := effective_template()
	var padding := template.effective_padding()
	var room := maxf(0.0, _box.size.x - padding.x - padding.z)
	_name.size = Vector2(minf(name_width(), room), _name.get_combined_minimum_size().y)
	var x := padding.x
	match template.name_align:
		TalkBoxTemplate.NameAlign.CENTER:
			x = (_box.size.x - _name.size.x) * 0.5
		TalkBoxTemplate.NameAlign.RIGHT:
			x = _box.size.x - padding.z - _name.size.x
	# The Panel fits even internal children to its content area; place the
	# name in the Panel's own coordinates.
	_name.position = Vector2(x, -_name.size.y * 0.5) + template.name_offset - _name_edge.position


func _bleed_rects() -> Array[Rect2]:
	var rects := super._bleed_rects()
	if _name.get_parent() == _name_edge and _name.visible:
		rects.append(Rect2(_name.position + _name_edge.position, _name.size))
	if _tail.visible and _tail.polygon.size() >= 3:
		# The tail hangs off the edge it was drawn on last frame.
		var template := effective_template()
		var reach := _tail_length() - template.tail_inset()
		var y := -reach if _tail_up else _box.size.y
		rects.append(Rect2(0.0, y, _box.size.x, reach))
	return rects


# Points the tail at the anchor's focus point; hides it when there is none. The
# tail hangs from the bottom edge, or from the top when the box had to sit
# below the speaker.
func _on_anchored(result: TalkAnchorResult) -> void:
	var template := effective_template()
	var wants_tail := template.tail_shown and result.has_focus
	_tail.visible = wants_tail
	if not wants_tail:
		return
	# In the box's own units, so a scaling transition carries the tail along.
	var to_box := _box.get_transform()
	var local_focus := to_box.affine_inverse() * result.focus
	_tail_up = local_focus.y < 0.0
	var margin := minf(template.tail_side_margin(), _box.size.x * 0.5)
	var along := clampf(local_focus.x, margin, _box.size.x - margin)
	var inset := template.tail_inset()
	var edge := inset if _tail_up else _box.size.y - inset
	var base := to_box * Vector2(along, edge)
	_tail.scale = _box.scale
	_tail.modulate.a = _box.modulate.a
	_tail.rotation = PI if _tail_up else 0.0
	if template.tail_aim == TalkBoxTemplate.TailAim.STRAIGHT:
		_tail.position = base.round()
		template.lean_tail(_tail, 0.0)
		return
	_tail.position = base
	# The tip leans toward the speaker, within reason, in the tail's own frame.
	var toward := (result.focus - base).rotated(-_tail.rotation)
	var slope := clampf(toward.x / maxf(toward.y, 1.0), -1.2, 1.2)
	template.lean_tail(_tail, slope * template.tail_size)


# How far the tail reaches from its base, in the box's units.
func _tail_length() -> float:
	var length := 0.0
	for polygon: Polygon2D in [_tail, _tail.get_node_or_null(^"Outline")]:
		if polygon != null:
			for point in polygon.polygon:
				length = maxf(length, point.y)
	return length


func apply_anchor() -> void:
	_layout_name_edge()
	super.apply_anchor()
	_layout_name_edge()
	if last_anchor != null and not last_anchor.visible:
		_tail.visible = false
