@tool
## Draws one [TalkBoxLayer] on the control of the slot it decorates. The
## renderer adds one per enabled layer as an internal child, so containers do
## not lay it out and user scenes never see it in get_children().
extends Control

var layer: TalkBoxLayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(new_layer: TalkBoxLayer, behind_parent: bool) -> void:
	layer = new_layer
	name = "Layer_%s" % new_layer.name.validate_node_name()
	texture_filter = new_layer.filter
	self_modulate = new_layer.tint
	# The Panel draws its own style under its children, so its behind layers
	# need no help. A label or portrait draws its content itself, so its behind
	# layers have to be drawn before the parent.
	show_behind_parent = behind_parent
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED, NOTIFICATION_VISIBILITY_CHANGED:
			queue_redraw()
		NOTIFICATION_PARENTED:
			var parent := get_parent_control()
			if parent != null and not parent.resized.is_connected(queue_redraw):
				parent.resized.connect(queue_redraw)


## The slot's rectangle in this view's coordinates. A container slot fits its
## children, internal ones included, to its content area; the slot itself
## starts back at the parent's origin.
func slot_rect() -> Rect2:
	var parent := get_parent_control()
	if parent == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(-position, parent.size)


## The area this layer paints, in the slot control's coordinates.
func painted_rect() -> Rect2:
	if layer == null:
		return Rect2()
	return layer.painted_rect_in(slot_rect())


func _draw() -> void:
	if layer != null:
		layer.draw(self, slot_rect())
