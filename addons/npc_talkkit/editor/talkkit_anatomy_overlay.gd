@tool
## The Anatomy Map: labels each part of the dialogue box on top of the live
## preview, and marks the eight positions a Panel decoration can sit at.
## Hovering explains a part; clicking one asks the owner to navigate there.
##
## It also draws the brief highlight the editor uses to point at a part.
extends Control

## A part was clicked: "panel", "name", "visual", "text", "continue" or "tail".
signal slot_clicked(slot: String)
## A Position marker was clicked.
signal position_clicked(spot: TalkBoxLayer.Position)

const SLOT_NAMES := {
	"panel": "Panel",
	"name": "Speaker Name",
	"visual": "Dialogue Visual",
	"text": "Text",
	"continue": "Continue Indicator",
	"tail": "Tail",
}
const SLOT_TIPS := {
	"panel": "The box's main background.",
	"name": "Displays the active speaker name.",
	"visual": "The speaker's portrait, avatar or bust.",
	"text": "The dialogue line.",
	"continue": "Shown when the player can advance.",
	"tail": "Points the box at the speaker. Shown only when the box follows a target.",
}
## Drawn largest first; hit-tested smallest first.
const DRAW_ORDER := ["panel", "visual", "name", "text", "continue", "tail"]
const MARKERS := [
	TalkBoxLayer.Position.TOP_LEFT, TalkBoxLayer.Position.TOP, TalkBoxLayer.Position.TOP_RIGHT,
	TalkBoxLayer.Position.LEFT, TalkBoxLayer.Position.RIGHT,
	TalkBoxLayer.Position.BOTTOM_LEFT, TalkBoxLayer.Position.BOTTOM, TalkBoxLayer.Position.BOTTOM_RIGHT,
]
const ACCENT := Color(0.35, 0.72, 1.0)

## The preview whose renderer is labelled.
var preview: TextureRect
## The box being edited, for the per-position layer counts.
var template: TalkBoxTemplate
## When true, labels are drawn outside the box with leader lines. Used by the
## larger, expanded map.
var callouts := false

var _on := false
var _hover := ""
var _flash := Rect2()
var _flash_alpha := 0.0
var _flash_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Any text enables _get_tooltip(), which supplies the real one.
	tooltip_text = " "
	set_process(false)


## Shows or hides the map. The highlight works either way.
func set_shown(value: bool) -> void:
	_on = value
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	_hover = ""
	set_process(value)
	queue_redraw()


## Briefly outlines [param slot] on the preview.
func flash_slot(slot: String) -> void:
	var rects := slot_rects()
	if rects.has(slot):
		flash(rects[slot])


## Briefly outlines [param layer]'s area, or its slot when it draws nothing.
func flash_layer(layer: TalkBoxLayer) -> void:
	var renderer := _renderer()
	if renderer == null or layer == null:
		return
	var rect: Rect2 = renderer.layer_rect(layer)
	if rect.has_area():
		flash(_to_local(rect))
		return
	flash_slot(["panel", "name", "visual"][layer.slot])


## Briefly outlines [param rect], in this control's coordinates. A rect off
## the preview is ignored rather than drawn somewhere misleading.
func flash(rect: Rect2) -> void:
	if preview != null and is_instance_valid(preview):
		var shown := Rect2(_to_local(preview.shown_region()))
		if not shown.grow(8.0).encloses(rect):
			return
	_flash = rect
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_alpha = 1.0
	set_process(true)
	if not is_inside_tree():
		return
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.5)
	_flash_tween.tween_property(self, "_flash_alpha", 0.0, 0.9)
	_flash_tween.finished.connect(func() -> void: set_process(_on))


## Each visible part of the box, in this control's coordinates.
func slot_rects() -> Dictionary:
	var renderer := _renderer()
	if renderer == null or not renderer.has_method("slot_rects"):
		return {}
	var rects := {}
	var found: Dictionary = renderer.slot_rects()
	for key in found:
		rects[key] = _to_local(found[key])
	return rects


## Where each Position marker sits, given the Panel's rectangle.
static func marker_points(panel: Rect2) -> Dictionary:
	return {
		TalkBoxLayer.Position.TOP_LEFT: panel.position,
		TalkBoxLayer.Position.TOP: Vector2(panel.get_center().x, panel.position.y),
		TalkBoxLayer.Position.TOP_RIGHT: Vector2(panel.end.x, panel.position.y),
		TalkBoxLayer.Position.LEFT: Vector2(panel.position.x, panel.get_center().y),
		TalkBoxLayer.Position.RIGHT: Vector2(panel.end.x, panel.get_center().y),
		TalkBoxLayer.Position.BOTTOM_LEFT: Vector2(panel.position.x, panel.end.y),
		TalkBoxLayer.Position.BOTTOM: Vector2(panel.get_center().x, panel.end.y),
		TalkBoxLayer.Position.BOTTOM_RIGHT: panel.end,
	}


## The area a Position covers on the Panel, for the hover highlight.
static func position_area(panel: Rect2, spot: int) -> Rect2:
	var band := 12.0
	var inset := minf(24.0, panel.size.x * 0.2)
	var point: Vector2 = marker_points(panel)[spot]
	match spot:
		TalkBoxLayer.Position.TOP, TalkBoxLayer.Position.BOTTOM:
			return Rect2(panel.position.x + inset, point.y - band * 0.5, panel.size.x - inset * 2.0, band)
		TalkBoxLayer.Position.LEFT, TalkBoxLayer.Position.RIGHT:
			return Rect2(point.x - band * 0.5, panel.position.y + inset, band, maxf(band, panel.size.y - inset * 2.0))
	return Rect2(point - Vector2(band, band), Vector2(band, band) * 2.0)


## What is under [param point]: "slot:<name>", "position:<index>", or "".
func hit(point: Vector2) -> String:
	var rects := slot_rects()
	if rects.has("panel") and _hover.begins_with("position:"):
		var area := position_area(rects["panel"], int(_hover.trim_prefix("position:")))
		draw_rect(area, Color(ACCENT, 0.22), true)
		draw_rect(area, ACCENT, false, 1.0)
	if rects.has("panel"):
		var points := marker_points(rects["panel"])
		for spot in MARKERS:
			if point.distance_to(points[spot]) <= 8.0:
				return "position:%d" % spot
	if callouts:
		var labels := _callout_labels(rects)
		for slot in labels:
			if labels[slot].grow(2.0).has_point(point):
				return "slot:" + slot
	var order := DRAW_ORDER.duplicate()
	order.reverse()
	for slot in order:
		if rects.has(slot) and (rects[slot] as Rect2).grow(2.0).has_point(point):
			return "slot:" + slot
	return ""


func _process(_delta: float) -> void:
	# The renderer settles over a few frames and the flash fades, so redraw
	# while either is happening.
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _on:
		return
	if event is InputEventMouseMotion:
		var hovered: String = hit(event.position)
		if hovered != _hover:
			_hover = hovered
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target: String = hit(event.position)
		if target.begins_with("slot:"):
			slot_clicked.emit(target.trim_prefix("slot:"))
			accept_event()
		elif target.begins_with("position:"):
			position_clicked.emit(int(target.trim_prefix("position:")) as TalkBoxLayer.Position)
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	if not _on:
		return ""
	var target := hit(at_position)
	if target.begins_with("slot:"):
		var slot := target.trim_prefix("slot:")
		return "%s\n%s\nClick to edit." % [SLOT_NAMES[slot], SLOT_TIPS[slot]]
	if target.begins_with("position:"):
		var spot := int(target.trim_prefix("position:"))
		var count := _count_at(spot)
		var use := "Used for corner ornaments and badges." if spot >= TalkBoxLayer.Position.TOP_LEFT else "Used for edge pieces."
		var action := (
			"Click to add a layer here." if count == 0
			else "%d layer%s here. Click to find %s." % [count, "" if count == 1 else "s", "it" if count == 1 else "them"])
		return "%s\nDecoration position on the Panel.\n%s\n%s" % [TalkBoxLayer.POSITION_NAMES[spot], use, action]
	return ""


func _draw() -> void:
	if _flash_alpha > 0.01 and _flash.has_area():
		draw_rect(_flash.grow(3.0), Color(ACCENT, 0.25 * _flash_alpha), true)
		draw_rect(_flash.grow(3.0), Color(ACCENT, _flash_alpha), false, 2.0)
	if not _on:
		return
	var rects := slot_rects()
	var font := get_theme_default_font()
	var font_size := 11
	for slot in DRAW_ORDER:
		if not rects.has(slot):
			continue
		var rect: Rect2 = rects[slot]
		var hovered: bool = _hover == "slot:" + slot
		if hovered:
			draw_rect(rect, Color(ACCENT, 0.18), true)
		_dashed_rect(rect, Color(ACCENT, 1.0 if hovered else 0.8))
	if callouts:
		var labels := _callout_labels(rects)
		for slot in labels:
			var label: Rect2 = labels[slot]
			var rect: Rect2 = rects[slot]
			var target := _nearest_point(rect, label.get_center()) if slot == "panel" else rect.get_center()
			draw_line(label.get_center(), target, ACCENT, 1.0, true)
			draw_circle(target, 2.5, ACCENT)
			_tag(label, SLOT_NAMES[slot], font, 13, _hover == "slot:" + slot)
	else:
		for slot in DRAW_ORDER:
			if rects.has(slot):
				var text: String = SLOT_NAMES[slot]
				var tag := _compact_tag_rect(slot, rects[slot], font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size))
				_tag(tag, text, font, font_size, _hover == "slot:" + slot)
	if rects.has("panel") and _hover.begins_with("position:"):
		var area := position_area(rects["panel"], int(_hover.trim_prefix("position:")))
		draw_rect(area, Color(ACCENT, 0.22), true)
		draw_rect(area, ACCENT, false, 1.0)
	if rects.has("panel"):
		var points := marker_points(rects["panel"])
		for spot in MARKERS:
			var point: Vector2 = points[spot]
			var hovered: bool = _hover == "position:%d" % spot
			var square := Rect2(point - Vector2(4.5, 4.5), Vector2(9.0, 9.0))
			draw_rect(square.grow(1.0 if hovered else 0.0), ACCENT if not hovered else Color.WHITE, true)
			var count := _count_at(spot)
			if count > 0:
				draw_string(font, point + Vector2(7.0, -5.0), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ACCENT)
			if callouts:
				var label_text: String = TalkBoxLayer.POSITION_NAMES[spot] + (" · %d" % count if count > 0 else "")
				var away := _away(spot) * 54.0
				var extent := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11) + Vector2(10.0, 6.0)
				var label := Rect2(point + away - extent * 0.5, extent)
				_dashed_line(point, label.get_center(), Color(ACCENT, 0.7))
				_tag(label, label_text, font, 11, hovered, true)


func _tag(rect: Rect2, text: String, font: Font, font_size: int, hovered: bool, outline := false) -> void:
	if outline:
		draw_rect(rect, Color(0.07, 0.11, 0.17, 0.95), true)
		draw_rect(rect, ACCENT, false, 1.0)
		draw_string(font, rect.position + Vector2(5.0, rect.size.y * 0.5 + font_size * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if hovered else Color(0.8, 0.9, 1.0))
		return
	draw_rect(rect, Color.WHITE if hovered else ACCENT, true)
	draw_string(font, rect.position + Vector2(4.0, rect.size.y * 0.5 + font_size * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.02, 0.08, 0.14))


# Small tags hugging each part, placed where they collide least.
func _compact_tag_rect(slot: String, rect: Rect2, text_size: Vector2) -> Rect2:
	var extent := text_size + Vector2(8.0, 4.0)
	match slot:
		"panel":
			return Rect2(Vector2(rect.end.x - extent.x, rect.position.y - extent.y - 1.0), extent)
		"text":
			return Rect2(Vector2(rect.end.x - extent.x, rect.position.y), extent)
		"visual":
			return Rect2(Vector2(rect.position.x, rect.end.y - extent.y), extent)
		"continue":
			return Rect2(Vector2(rect.position.x - extent.x - 3.0, rect.position.y), extent)
		"tail":
			return Rect2(Vector2(rect.end.x + 3.0, rect.position.y), extent)
	return Rect2(Vector2(rect.position.x, rect.position.y - extent.y - 1.0), extent)


# Callout labels around the Panel, clear of the box.
func _callout_labels(rects: Dictionary) -> Dictionary:
	var labels := {}
	if not rects.has("panel"):
		return labels
	var panel: Rect2 = rects["panel"]
	var font := get_theme_default_font()
	var spots := {
		"name": Vector2(panel.position.x + panel.size.x * 0.28, panel.position.y - 78.0),
		"panel": Vector2(panel.end.x + 96.0, panel.position.y + 14.0),
		"visual": Vector2(panel.position.x + 40.0, panel.end.y + 70.0),
		"text": Vector2(panel.position.x + panel.size.x * 0.6, panel.end.y + 96.0),
		"tail": Vector2(panel.position.x + panel.size.x * 0.32, panel.end.y + 122.0),
		"continue": Vector2(panel.end.x - 40.0, panel.end.y + 70.0),
	}
	for slot in spots:
		if rects.has(slot):
			var extent := font.get_string_size(SLOT_NAMES[slot], HORIZONTAL_ALIGNMENT_LEFT, -1, 13) + Vector2(14.0, 10.0)
			labels[slot] = Rect2(spots[slot] - extent * 0.5, extent)
	return labels


static func _away(spot: TalkBoxLayer.Position) -> Vector2:
	match spot:
		TalkBoxLayer.Position.TOP_LEFT: return Vector2(-1.4, -1.0)
		TalkBoxLayer.Position.TOP: return Vector2(0.0, -1.0)
		TalkBoxLayer.Position.TOP_RIGHT: return Vector2(1.4, -1.0)
		TalkBoxLayer.Position.LEFT: return Vector2(-1.6, 0.0)
		TalkBoxLayer.Position.RIGHT: return Vector2(1.6, 0.0)
		TalkBoxLayer.Position.BOTTOM_LEFT: return Vector2(-1.4, 1.0)
		TalkBoxLayer.Position.BOTTOM: return Vector2(0.0, 1.0)
	return Vector2(1.4, 1.0)


static func _nearest_point(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))


func _dashed_rect(rect: Rect2, color: Color) -> void:
	_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color)
	_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color)
	_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color)
	_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color)


func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	draw_dashed_line(from, to, color, 1.0, 4.0)


func _count_at(spot: int) -> int:
	if template == null:
		return 0
	var count := 0
	for layer in template.layers_for(TalkBoxLayer.Slot.PANEL):
		if layer.position == spot:
			count += 1
	return count


func _renderer() -> Node:
	if preview == null or not is_instance_valid(preview) or not preview.has_method("get_renderer"):
		return null
	return preview.get_renderer()


# From the preview viewport to this control, wherever the preview sits.
func _to_local(rect: Rect2) -> Rect2:
	var local: Rect2 = preview.viewport_to_local(rect)
	var offset := preview.get_global_rect().position - get_global_rect().position
	return Rect2(local.position + offset, local.size)
