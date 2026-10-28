@tool
## A dialogue box style: which parts it shows, how they are painted, and how it
## animates.
##
## Settings are grouped by the part of the box they affect. The Panel's look is
## its Base Appearance; extra decorations such as a name box, a portrait frame
## or corner ornaments are [TalkBoxLayer]s in [member layers].
##
## Save one as a .tres to share it between NPCs.
@icon("res://addons/npc_talkkit/icons/talk_box_template.svg")
class_name TalkBoxTemplate
extends Resource

## Which side of the box the dialogue visual sits on.
enum VisualSide { LEFT, RIGHT }
## Where the speaker's name sits.
enum NamePlacement { INLINE, TOP_EDGE }
enum NameAlign { LEFT, CENTER, RIGHT }
## How the tail is painted on a textured panel. A flat panel's tail always
## takes the panel colour.
enum TailLook { COLOR, IMAGE }
## Whether the tail's tip leans toward the speaker or points straight out of
## its edge. Straight keeps pixel-art tails on the pixel grid.
enum TailAim { SPEAKER, STRAIGHT }
enum IndicatorLook { GLYPH, IMAGE }
## The continue indicator's idle motion.
enum IndicatorMotion { NONE, BOUNCE, BLINK }

## Settings a Theme controls while one is assigned.
const PORTRAIT_CLIP := preload("res://addons/npc_talkkit/box/portrait_clip.gdshader")
const THEMED := ["font", "text_size", "text_color", "name_font", "name_size", "name_color"]


@export_group("Panel")
## The Panel's Base Appearance: a [TalkBoxLayer] edited with the same
## Appearance controls as a name box, a frame or any layer.
@export var base: TalkBoxLayer:
	set(value):
		base = value
		if base != null:
			base.is_base = true
			base.slot = TalkBoxLayer.Slot.PANEL
			base.position = TalkBoxLayer.Position.FILL
			base.depth = TalkBoxLayer.Depth.BEHIND

@export_group("Text")
@export var font: Font
## Zero inherits the size from the theme.
@export_range(0, 96, 1) var text_size := 20
@export var text_color := Color(1.0, 1.0, 1.0, 1.0)
@export_range(-16, 48, 1) var line_spacing := 0
## Minimum size of the text area. x is also the wrap width.
@export var text_min_size := Vector2(0.0, 76.0)
## Typewriter speed in characters per second. Zero shows the whole line at once.
@export_range(0.0, 240.0, 1.0) var typewriter_speed := 40.0

@export_group("Speaker Name")
@export var name_shown := true:
	set(value):
		name_shown = value
		notify_property_list_changed()
## Inline puts the name above the text; On top edge sits it across the
## Panel's top border.
@export var name_placement: NamePlacement = NamePlacement.INLINE:
	set(value):
		name_placement = value
		notify_property_list_changed()
@export var name_align: NameAlign = NameAlign.LEFT
## Fine-tunes the name's position on the top edge.
@export var name_offset := Vector2.ZERO
@export var name_font: Font
@export_range(0, 96, 1) var name_size := 22
@export var name_color := Color(1.0, 0.78, 0.32, 1.0)

@export_group("Dialogue Visual")
## Whether the speaker's visual is drawn.
@export var visual_shown := true:
	set(value):
		visual_shown = value
		notify_property_list_changed()
## The portrait's size. Zero keeps the renderer's own size, or the image's
## size when the renderer sets none.
@export var visual_size := Vector2(120.0, 120.0)
@export var visual_side: VisualSide = VisualSide.LEFT
@export_range(0, 64, 1) var visual_spacing := 18
## Texture filter for the visual. The default follows the project setting; use
## Nearest for pixel art.
@export var visual_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
## Cuts the portrait to its frame's rounded corners, so a round frame shows a
## round portrait. Off lets a character reach past the frame.
@export var visual_clip_to_frame := false

@export_group("Tail")
## A tail pointing at the speaker. Hidden when the placement has no target to
## point at.
@export var tail_shown := false:
	set(value):
		tail_shown = value
		notify_property_list_changed()
## On a textured panel, a flat colour or an image. A flat panel's tail takes
## the panel colour.
@export var tail_look: TailLook = TailLook.COLOR:
	set(value):
		tail_look = value
		notify_property_list_changed()
@export var tail_color := Color(0.91, 0.85, 0.69, 1.0)
## Points down; Tail Aim decides whether it leans toward the speaker. An
## AtlasTexture uses its region.
@export var tail_texture: Texture2D
## How far the tail reaches from the Panel's edge.
@export_range(4.0, 64.0, 1.0) var tail_size := 16.0
## How wide the tail is where it meets the Panel. 0, shown as Auto, follows
## the size.
@export_range(0.0, 96.0, 1.0) var tail_width := 0.0
@export var tail_aim: TailAim = TailAim.SPEAKER
## How far the tail tucks under the Panel's bottom edge, so both read as one
## shape. Hidden on a bordered flat Panel, whose tail covers the border.
@export_range(0.0, 32.0, 1.0) var tail_overlap := 2.0

@export_group("Continue Indicator")
@export var continue_shown := true:
	set(value):
		continue_shown = value
		notify_property_list_changed()
@export var continue_look: IndicatorLook = IndicatorLook.GLYPH:
	set(value):
		continue_look = value
		notify_property_list_changed()
@export var continue_text := "▼"
## An AtlasTexture uses its region.
@export var continue_texture: Texture2D
## Texture filter for the indicator image. Use Nearest for pixel art.
@export var continue_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
@export var continue_motion: IndicatorMotion = IndicatorMotion.NONE

@export_group("Transitions")
@export_enum("none", "fade", "slide", "scale_pop") var open_transition := "fade"
@export_enum("none", "fade", "slide", "scale_pop") var close_transition := "fade"
## Applied when the box moves to the next line without closing.
@export_enum("none", "fade", "slide", "scale_pop") var line_transition := "none"
@export_range(0.0, 2.0, 0.01) var transition_duration := 0.18
@export var transition_curve: Tween.TransitionType = Tween.TRANS_CUBIC
@export var transition_easing: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced")
## Replaces the open, close and line transitions. Subclass [TalkTransition] for
## custom effects.
@export var custom_transition: TalkTransition
## Governs fonts, font sizes and text colours. While set, this template's own
## font and colour settings stand down. The Panel, padding, layers and layout
## always apply.
@export var theme: Theme:
	set(value):
		theme = value
		notify_property_list_changed()
## A custom renderer scene, for layouts the settings and layers cannot
## describe. Its root must extend [TalkBoxRenderer]. Empty uses the built-in box.
@export var renderer: PackedScene

## Decorations on the Panel, Speaker Name and Dialogue Visual, bottom to top
## within each depth. Edited in the workspace's Layers view.
@export_storage var layers: Array[TalkBoxLayer] = []


## Editor-only rows that list a slot's layers, keyed by the group they sit in.
## Not stored; the workspace draws them as a summary, Open in Layers and Add.
const LAYER_ROWS := {
	"panel_decorations": ["Panel", TalkBoxLayer.Slot.PANEL],
	"name_box": ["Speaker Name", TalkBoxLayer.Slot.SPEAKER_NAME],
	"frame": ["Dialogue Visual", TalkBoxLayer.Slot.DIALOGUE_VISUAL],
}
## Prefixes under which a box's Appearance is shown in these settings: the
## Panel's base always, and a single name box or frame.
const BOX_PREFIXES := {"panel_": -1, "name_box_": TalkBoxLayer.Slot.SPEAKER_NAME, "frame_": TalkBoxLayer.Slot.DIALOGUE_VISUAL}


func _init() -> void:
	base = default_base()


## The Base Appearance a new box starts with: the classic dark panel.
static func default_base() -> TalkBoxLayer:
	var layer := TalkBoxLayer.new()
	layer.name = "Base Appearance"
	layer.visual_source = TalkBoxLayer.Source.FLAT_STYLE
	var flat := layer.style as StyleBoxFlat
	flat.bg_color = Color(0.055, 0.065, 0.09, 0.96)
	flat.border_color = Color(0.35, 0.42, 0.58, 1.0)
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(12)
	layer.padding = Vector4(20.0, 16.0, 20.0, 16.0)
	return layer


# The Appearance editors and the layer rows, added outside the exports so
# they carry no default to revert to; the inspector files each under its
# group by name. The Panel's base shows here always; a name box or frame
# shows here when its slot has exactly one, so a simple one never needs the
# Layers view.
func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for row in LAYER_ROWS:
		var slot: TalkBoxLayer.Slot = LAYER_ROWS[row][1]
		list.append({"name": LAYER_ROWS[row][0], "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP,
			"hint_string": "panel_" if slot == TalkBoxLayer.Slot.PANEL else ""})
		var box := base if slot == TalkBoxLayer.Slot.PANEL else _only_layer(slot)
		if box != null:
			var prefix := _prefix_for(slot)
			if slot != TalkBoxLayer.Slot.PANEL:
				list.append({"name": row.capitalize(), "type": TYPE_NIL, "usage": PROPERTY_USAGE_SUBGROUP, "hint_string": prefix})
			for entry in box.look_properties():
				var shown := entry.duplicate()
				shown["name"] = prefix + String(entry["name"])
				list.append(shown)
		list.append({"name": row, "type": TYPE_INT, "usage": PROPERTY_USAGE_EDITOR})
	return list


func _get(property: StringName) -> Variant:
	var name := String(property)
	if LAYER_ROWS.has(name):
		return layers_for(LAYER_ROWS[name][1]).size()
	var box := _box_for(name)
	if box.is_empty():
		return null
	return (box["layer"] as TalkBoxLayer).get(box["property"])


func _set(property: StringName, value: Variant) -> bool:
	var box := _box_for(String(property))
	if box.is_empty():
		return false
	(box["layer"] as TalkBoxLayer).set(box["property"], value)
	if box["property"] in ["appearance", "shadow_size", "padding_mode", "resource", "border_width", "border_color"]:
		notify_property_list_changed()
	emit_changed()
	return true


## What the Padding row shows for the box under [param prefix].
func padding_info(prefix := "panel_") -> Dictionary:
	var box := _box_for(prefix + "padding_mode")
	return (box["layer"] as TalkBoxLayer).padding_info() if not box.is_empty() else {}


static func _prefix_for(slot: TalkBoxLayer.Slot) -> String:
	for prefix in BOX_PREFIXES:
		if BOX_PREFIXES[prefix] == (slot if slot != TalkBoxLayer.Slot.PANEL else -1):
			return prefix
	return ""


func _only_layer(slot: TalkBoxLayer.Slot) -> TalkBoxLayer:
	var found := layers_for(slot)
	return found[0] if found.size() == 1 else null


# {"layer", "property"} for a property shown under one of BOX_PREFIXES, or {}.
func _box_for(name: String) -> Dictionary:
	for prefix in BOX_PREFIXES:
		if not name.begins_with(prefix):
			continue
		var slot: int = BOX_PREFIXES[prefix]
		var layer := base if slot < 0 else _only_layer(slot as TalkBoxLayer.Slot)
		if layer != null:
			return {"layer": layer, "property": name.trim_prefix(prefix)}
	return {}


# Hides settings that do not apply, and marks the ones a Theme controls.
func _validate_property(property: Dictionary) -> void:
	var name := String(property.name)
	match name:
		"resource_local_to_scene", "resource_path", "resource_name", "script":
			property.usage &= ~PROPERTY_USAGE_EDITOR
			return
		"visual_filter", "continue_filter":
			property.hint_string = TalkBoxLayer.FILTER_NAMES
	var hide := false
	match name:
		"name_align", "name_offset":
			hide = not name_shown or name_placement != NamePlacement.TOP_EDGE
		"tail_look":
			hide = not tail_shown or not is_textured()
		"tail_color":
			hide = not tail_shown or not is_textured() or tail_look != TailLook.COLOR
		"tail_texture":
			hide = not tail_shown or not is_textured() or tail_look != TailLook.IMAGE
		"tail_overlap":
			# A bordered flat Panel's tail covers exactly the border instead.
			hide = not tail_shown or tail_border() > 0.0
		"continue_text":
			hide = not continue_shown or continue_look != IndicatorLook.GLYPH
		"continue_texture", "continue_filter":
			hide = not continue_shown or continue_look != IndicatorLook.IMAGE
		"continue_look", "continue_motion":
			hide = not continue_shown
		_:
			if name.begins_with("visual_") and name != "visual_shown":
				hide = not visual_shown
			elif name.begins_with("tail_") and name != "tail_shown":
				hide = not tail_shown
			elif name.begins_with("name_") and name != "name_shown":
				hide = not name_shown
	if hide:
		property.usage = PROPERTY_USAGE_NO_EDITOR if property.usage & PROPERTY_USAGE_STORAGE else 0
		return
	if theme != null and name in THEMED:
		property.usage |= PROPERTY_USAGE_READ_ONLY


#region Panel

## True when the Panel is drawn from an image rather than a flat colour.
func is_textured() -> bool:
	if base == null:
		return false
	match base.visual_source:
		TalkBoxLayer.Source.FLAT_STYLE:
			return false
		TalkBoxLayer.Source.RESOURCE:
			return base.style is not StyleBoxFlat
	return true


## True when the tail is painted with [member tail_texture].
func tail_draws_image() -> bool:
	return tail_shown and is_textured() and tail_look == TailLook.IMAGE


## True when the renderer draws the Base Appearance like a layer under the
## content: an image, or any StyleBox that is not flat, so its Image Filter
## applies. A flat Panel is the box's own StyleBox.
func base_draws_in_view() -> bool:
	return base != null and (base.draws_texture() or (base.style != null and base.style is not StyleBoxFlat))


## The StyleBox that paints the Panel, at its scale; null for an image base.
func drawn_panel_style() -> StyleBox:
	if base == null or base.style == null or base.draws_texture():
		return null
	return TalkBoxLayer.scaled_style(base.style, base.scale, not TalkBoxLayer.is_pixel_filter(base.filter))


## The Panel's StyleBox, with the effective padding as its content margins. A
## StyleBox resource is copied, never modified. A base the renderer draws as a
## layer leaves this StyleBox only the padding.
func build_panel_style() -> StyleBox:
	var margins := effective_padding()
	var box: StyleBox
	if base_draws_in_view() or drawn_panel_style() == null:
		box = StyleBoxEmpty.new()
	else:
		box = drawn_panel_style().duplicate()
	for side in 4:
		box.set_content_margin(side, margins[side])
	return box


## The margins the Panel's own style gives. A flat panel has none.
func style_margins() -> Vector4:
	return base.style_margins() if base != null else Vector4.ZERO


## The space between the Panel and its content that actually applies.
func effective_padding() -> Vector4:
	return base.effective_padding() if base != null else Vector4.ZERO


## The filter for the Panel's images, which the tail and indicator images
## follow too.
func image_filter() -> CanvasItem.TextureFilter:
	return base.filter if base != null else CanvasItem.TEXTURE_FILTER_PARENT_NODE


## The Panel's main colour: what a flat tail takes, and what "Sample panel
## colour" picks for a textured one.
func panel_color() -> Color:
	if base == null:
		return tail_color
	if base.style is StyleBoxFlat:
		return (base.style as StyleBoxFlat).bg_color
	var texture: Texture2D = base.texture
	if base.style is StyleBoxTexture:
		texture = (base.style as StyleBoxTexture).texture
	var image := texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		return tail_color
	if image.is_compressed():
		image = image.duplicate() as Image
		image.decompress()
	return image.get_pixel(image.get_width() / 2, image.get_height() / 2)

#endregion


#region Layers

## The enabled and disabled layers on [param slot], in drawing order.
## The corner radii the portrait is cut to: its frame's, less how far the frame
## reaches past the portrait. [code]null[/code] when it is not cut.
func visual_clip_radii() -> Variant:
	if not visual_clip_to_frame:
		return null
	for layer in layers_for(TalkBoxLayer.Slot.DIALOGUE_VISUAL):
		if layer.enabled and layer.position == TalkBoxLayer.Position.FILL and layer.style is StyleBoxFlat:
			var frame := layer.style as StyleBoxFlat
			return Vector4(
				maxf(0.0, frame.corner_radius_top_left - maxf(frame.expand_margin_left, frame.expand_margin_top)),
				maxf(0.0, frame.corner_radius_top_right - maxf(frame.expand_margin_right, frame.expand_margin_top)),
				maxf(0.0, frame.corner_radius_bottom_right - maxf(frame.expand_margin_right, frame.expand_margin_bottom)),
				maxf(0.0, frame.corner_radius_bottom_left - maxf(frame.expand_margin_left, frame.expand_margin_bottom)))
	return Vector4.ZERO


# Masks the portrait with PORTRAIT_CLIP, leaving a material the box's own scene
# set alone.
func _apply_visual_clip(visual: TextureRect) -> void:
	var radii: Variant = visual_clip_radii()
	var clip := visual.material as ShaderMaterial if visual.has_meta(&"talkkit_clip") else null
	if radii == null:
		if clip != null:
			visual.material = null
			visual.remove_meta(&"talkkit_clip")
		return
	if clip == null:
		if visual.material != null:
			return
		clip = ShaderMaterial.new()
		clip.shader = PORTRAIT_CLIP
		visual.material = clip
		visual.set_meta(&"talkkit_clip", true)
		visual.resized.connect(func() -> void:
			if visual.material is ShaderMaterial:
				(visual.material as ShaderMaterial).set_shader_parameter(&"rect_size", visual.size))
	clip.set_shader_parameter(&"radii", radii)
	clip.set_shader_parameter(&"rect_size", visual.size)


func layers_for(slot: TalkBoxLayer.Slot) -> Array[TalkBoxLayer]:
	var found: Array[TalkBoxLayer] = []
	for layer in layers:
		if layer != null and layer.slot == slot:
			found.append(layer)
	return found

#endregion


## Applies this template to a box's parts. Any part may be null.
func apply_to(
	box: Control,
	text: RichTextLabel = null,
	name_label: Label = null,
	visual: TextureRect = null,
	indicator: Label = null,
	tail: Polygon2D = null,
	content: BoxContainer = null,
	indicator_image: TextureRect = null,
) -> void:
	var paints := theme == null
	if box != null:
		# Leaves a theme the renderer's own scene set, unless a template set one.
		if theme != null:
			box.theme = theme
			box.set_meta(&"talkkit_theme", true)
		elif box.has_meta(&"talkkit_theme"):
			box.theme = null
			box.remove_meta(&"talkkit_theme")
		box.add_theme_stylebox_override("panel", build_panel_style())

	if text != null:
		text.custom_minimum_size = text_min_size
		if paints:
			# RichTextLabel theme items are "normal_font" and "default_color";
			# [color] tags in the line still take precedence.
			# A box reused for the next line drops the previous template's font.
			if font != null:
				text.add_theme_font_override("normal_font", font)
			else:
				text.remove_theme_font_override("normal_font")
			if text_size > 0:
				text.add_theme_font_size_override("normal_font_size", text_size)
			else:
				text.remove_theme_font_size_override("normal_font_size")
			text.add_theme_color_override("default_color", text_color)
		else:
			text.remove_theme_font_override("normal_font")
			text.remove_theme_font_size_override("normal_font_size")
			text.remove_theme_color_override("default_color")
		text.add_theme_constant_override("line_separation", line_spacing)
		# The Panel draws the background; stop a theme's RichTextLabel panel
		# from painting over it.
		text.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	if name_label != null:
		name_label.visible = name_shown and not name_label.text.is_empty()
		if paints:
			_font(name_label, name_font, name_size)
			name_label.add_theme_color_override("font_color", name_color)
		else:
			name_label.remove_theme_font_override("font")
			name_label.remove_theme_font_size_override("font_size")
			name_label.remove_theme_color_override("font_color")

	if visual != null:
		visual.texture_filter = visual_filter
		# Remembered once, so a box reused by another template can go back to it.
		if not visual.has_meta(&"talkkit_scene_size"):
			visual.set_meta(&"talkkit_scene_size", visual.custom_minimum_size)
			visual.set_meta(&"talkkit_scene_expand", visual.expand_mode)
		var size: Vector2 = visual_size if visual_size != Vector2.ZERO else visual.get_meta(&"talkkit_scene_size")
		visual.custom_minimum_size = size
		visual.expand_mode = TextureRect.EXPAND_KEEP_SIZE if size == Vector2.ZERO \
			else visual.get_meta(&"talkkit_scene_expand")
		_apply_visual_clip(visual)

	# An Image look with no image yet shows nothing, not the hidden glyph.
	var image_indicator := continue_look == IndicatorLook.IMAGE
	if indicator != null:
		indicator.text = continue_text
		indicator.visible = continue_shown and not image_indicator
		if paints:
			indicator.add_theme_color_override("font_color", text_color)
		else:
			indicator.remove_theme_color_override("font_color")
	if indicator_image != null:
		indicator_image.texture = continue_texture
		indicator_image.texture_filter = continue_filter
		indicator_image.visible = continue_shown and image_indicator

	if tail != null:
		_apply_tail(tail)

	if content != null:
		content.add_theme_constant_override("separation", visual_spacing)
		# Reorder the visual to the requested side.
		if visual != null and visual.get_parent() == content:
			var wanted := 0 if visual_side == VisualSide.LEFT else content.get_child_count() - 1
			if visual.get_index() != wanted:
				content.move_child(visual, wanted)


# A flat triangle in the Panel's colour, or the tail image on a textured panel.
# Both point down from the origin; the renderer leans them toward the speaker.
func _apply_tail(tail: Polygon2D) -> void:
	tail.visible = tail_shown
	tail.texture_filter = image_filter()
	var outline := _tail_outline(tail)
	outline.polygon = PackedVector2Array()
	if tail_draws_image() and tail_texture == null:
		# An Image look with no image yet draws nothing, not the hidden colour.
		tail.texture = null
		tail.polygon = PackedVector2Array()
		return
	if tail_draws_image():
		var drawn: Texture2D = tail_texture
		var region := Rect2(Vector2.ZERO, tail_texture.get_size())
		if tail_texture is AtlasTexture and (tail_texture as AtlasTexture).atlas != null:
			drawn = (tail_texture as AtlasTexture).atlas
			region = (tail_texture as AtlasTexture).region
		var half := tail_half_width()
		if tail_width <= 0.0:
			half = maxf(half * region.size.x / maxf(1.0, region.size.y), tail_size * 0.5)
		var length := tail_size * 1.5
		tail.texture = drawn
		tail.color = Color.WHITE
		tail.polygon = PackedVector2Array([
			Vector2(-half, 0.0), Vector2(half, 0.0),
			Vector2(half, length), Vector2(-half, length)])
		tail.uv = PackedVector2Array([
			region.position, Vector2(region.end.x, region.position.y),
			region.end, Vector2(region.position.x, region.end.y)])
		lean_tail(tail, 0.0)
		return
	tail.texture = null
	tail.uv = PackedVector2Array()
	tail.color = tail_color if is_textured() else panel_color()
	if tail_border() > 0.0:
		outline.color = (drawn_panel_style() as StyleBoxFlat).border_color
	lean_tail(tail, 0.0)


## Moves the tail's tip [param lean] pixels sideways while its base stays on
## the Panel's edge, so the base never lifts off a rounded or bordered edge.
## A flat Panel's border carries on around the tail.
func lean_tail(tail: Polygon2D, lean: float) -> void:
	if tail_draws_image():
		tail.skew = -atan2(lean, tail_size * 1.5)
		return
	if tail.texture != null or not tail_shown:
		return
	tail.skew = 0.0
	var half := tail_half_width()
	var length := tail_size
	tail.polygon = PackedVector2Array([
		Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(lean, length)])
	var outline := _tail_outline(tail)
	var border := tail_border()
	if border <= 0.0:
		outline.polygon = PackedVector2Array()
		return
	# Each slanted edge pushed out by the border width.
	var right := Vector2(lean - half, length).length()
	var left := Vector2(lean + half, length).length()
	var tip_y := length + border * (right + left) / (2.0 * half)
	var tip_x := (length * half + border * right - (half - lean) * tip_y) / length
	outline.polygon = PackedVector2Array([
		Vector2(-half - border * left / length, 0.0),
		Vector2(half + border * right / length, 0.0),
		Vector2(tip_x, tip_y)])


# The child that draws the tail's border, made on first use.
func _tail_outline(tail: Polygon2D) -> Polygon2D:
	var outline := tail.get_node_or_null(^"Outline") as Polygon2D
	if outline == null:
		outline = Polygon2D.new()
		outline.name = &"Outline"
		outline.show_behind_parent = true
		tail.add_child(outline, false, Node.INTERNAL_MODE_FRONT)
	outline.texture_filter = tail.texture_filter
	return outline


## Half the tail's width where it meets the Panel.
func tail_half_width() -> float:
	return tail_width * 0.5 if tail_width > 0.0 else tail_size * 0.75


## The width of the flat Panel's border that runs on around the tail, or 0.
func tail_border() -> float:
	if not tail_shown or is_textured() or base_draws_in_view():
		return 0.0
	var style := drawn_panel_style() as StyleBoxFlat
	if style == null or style.border_color.a <= 0.0:
		return 0.0
	return float(maxi(style.border_width_bottom, style.border_width_top))


## How far the tail tucks under the Panel's edge. A bordered Panel's tail
## covers exactly the border, so the two read as one outline.
func tail_inset() -> float:
	var border := tail_border()
	return border if border > 0.0 else tail_overlap


## The closest the tail's centre comes to the Panel's side edges, clear of
## its rounded corners.
func tail_side_margin() -> float:
	var corner := 0.0
	var style := drawn_panel_style() as StyleBoxFlat
	if style != null and not base_draws_in_view():
		corner = float(maxi(style.corner_radius_bottom_left, style.corner_radius_bottom_right))
	return maxf(20.0, corner + tail_half_width() + tail_border())


const _KINDS := {
	"none": TalkTransition.Kind.NONE,
	"fade": TalkTransition.Kind.FADE,
	"slide": TalkTransition.Kind.SLIDE,
	"scale_pop": TalkTransition.Kind.SCALE_POP,
}


## The transition for [param slot]: "open", "close" or "line".
func transition_for(slot: String) -> TalkTransition:
	if custom_transition != null:
		return custom_transition
	var named := open_transition
	if slot == "close":
		named = close_transition
	elif slot == "line":
		named = line_transition
	var transition := TalkTransition.builtin(
		_KINDS.get(named, TalkTransition.Kind.NONE), transition_duration)
	transition.curve = transition_curve
	transition.easing = transition_easing
	return transition


func _font(label: Label, face: Font, size: int) -> void:
	if face != null:
		label.add_theme_font_override("font", face)
	else:
		label.remove_theme_font_override("font")
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	else:
		label.remove_theme_font_size_override("font_size")
