@tool
## One decoration on a part of the dialogue box: a name box, a portrait frame,
## a corner ornament, an edge strip or an extra background.
##
## A layer draws a native Godot resource, a [StyleBox] or a [Texture2D]
## (including an [AtlasTexture] region), so nothing is locked into a TalkKit
## format. Layers live in [member TalkBoxTemplate.layers].
@icon("res://addons/npc_talkkit/icons/talk_box_template.svg")
class_name TalkBoxLayer
extends Resource

## The part of the box a layer decorates. Text, Tail and Continue Indicator
## have their own settings on [TalkBoxTemplate] and take no layers.
enum Slot { PANEL, SPEAKER_NAME, DIALOGUE_VISUAL }
## Where the layer sits on its slot.
enum Position { FILL, TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }
## Whether the layer is drawn under or over the slot's content.
enum Depth { BEHIND, ABOVE }
## What the layer draws. Flat Style is a [StyleBoxFlat], Nine-slice Texture a
## [StyleBoxTexture], Image a [Texture2D], and Existing Godot Resource any
## [StyleBox] or [Texture2D] you already have.
enum Source { FLAT_STYLE, NINE_SLICE, IMAGE, RESOURCE }
## How an image fills a Fill or edge layer.
enum Fit { STRETCH, TILE, TILE_FIT, KEEP_SIZE }
## Where a box's padding comes from.
enum PaddingMode { STYLE_MARGINS, CUSTOM }

const SLOT_NAMES := ["Panel", "Speaker Name", "Dialogue Visual"]
const POSITION_NAMES := ["Fill", "Top", "Bottom", "Left", "Right", "Top Left", "Top Right", "Bottom Left", "Bottom Right"]
const SOURCE_NAMES := ["Flat Style", "Nine-slice Texture", "Image", "Existing Godot Resource"]
## Corners and edges with no source of their own size use this.
const FALLBACK_SIZE := Vector2(16.0, 16.0)
const SOURCE_CHOICES := "Flat Style (StyleBoxFlat),Nine-slice Texture (StyleBoxTexture),Image (Texture2D),Existing Godot Resource (StyleBox or Texture2D)"
const STRETCH_NAMES := "Stretch,Tile,Tile Fit"
## Names for CanvasItem.TextureFilter in the order of its values.
const FILTER_NAMES := "Project Setting,Pixel (Nearest),Smooth (Linear),Pixel with Mipmaps,Smooth with Mipmaps,Pixel with Anisotropic Mipmaps,Smooth with Anisotropic Mipmaps"

@export var name := "Layer"
@export var enabled := true
@export var slot: Slot = Slot.PANEL
@export var position: Position = Position.FILL
@export var depth: Depth = Depth.BEHIND
## Moves the layer. Negative values let ornaments overhang the panel border.
@export var offset := Vector2.ZERO
## Corner and edge layers only. Zero uses the source's own size.
@export var size := Vector2.ZERO
## Edge layers only: space left free at both ends, so the edge runs between two
## corner ornaments instead of under them.
@export var edge_inset := 0.0
## Colour multiplier, so one asset can serve several colour schemes.
@export var tint := Color.WHITE

# The appearance is stored below and edited through look_properties(), the one
# Appearance editor shared by the Panel, a name box, a frame and every layer.
@export_storage var visual_source: Source = Source.IMAGE:
	set(value):
		visual_source = value
		_match_style_to_source()
		notify_property_list_changed()
## Drawn for Flat Style, Nine-slice Texture, and a StyleBox resource.
@export_storage var style: StyleBox
## Drawn for Image, and a Texture2D resource. An AtlasTexture draws its region.
@export_storage var texture: Texture2D
## Whole-number scale that keeps pixel art crisp.
@export_storage var scale := 1
## How an image fills its area.
@export_storage var fit: Fit = Fit.STRETCH
## The default follows the project setting; use Nearest for pixel art.
@export_storage var filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
## A nine-slice or StyleBox resource can pad with its own margins; everything
## else uses [member padding].
@export_storage var padding_mode: PaddingMode = PaddingMode.STYLE_MARGINS
## Space between this box and what it holds: left, top, right, bottom. Never
## written into the StyleBox, so a shared resource is left untouched.
@export_storage var padding := Vector4.ZERO
## Set by [TalkBoxTemplate] on the layer that is its Panel's Base Appearance.
var is_base := false


# Shows only the settings that apply to this layer's position.
func _validate_property(property: Dictionary) -> void:
	match String(property.name):
		"depth":
			property.hint_string = "Behind content,Above content"
		"resource_local_to_scene", "resource_path", "resource_name", "script":
			property.usage &= ~PROPERTY_USAGE_EDITOR
		"size":
			if position == Position.FILL:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		"edge_inset":
			# A Keep Size edge is centred on its side, so it has no inset.
			if not is_edge() or (fit == Fit.KEEP_SIZE and draws_texture()):
				property.usage = PROPERTY_USAGE_NO_EDITOR


func _get_property_list() -> Array[Dictionary]:
	return look_properties()


## The Appearance editor: the controls for this box's Visual Source, as
## editor-only properties. The Panel, a name box, a frame and every layer show
## exactly this list, so the same source is always edited the same way.
func look_properties() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var add := func(prop_name: String, type: int, hint := PROPERTY_HINT_NONE, hint_string := "") -> void:
		list.append({"name": prop_name, "type": type, "hint": hint, "hint_string": hint_string, "usage": PROPERTY_USAGE_EDITOR})
	add.call("appearance", TYPE_INT, PROPERTY_HINT_ENUM, SOURCE_CHOICES)
	match visual_source:
		Source.FLAT_STYLE:
			add.call("background", TYPE_COLOR)
			add.call("border_color", TYPE_COLOR)
			add.call("border_width", TYPE_INT, PROPERTY_HINT_RANGE, "0,32,1")
			add.call("corner_radius", TYPE_INT, PROPERTY_HINT_RANGE, "0,64,1")
			add.call("shadow_size", TYPE_INT, PROPERTY_HINT_RANGE, "0,64,1")
			if style is StyleBoxFlat and (style as StyleBoxFlat).shadow_size > 0:
				add.call("shadow_color", TYPE_COLOR)
		Source.NINE_SLICE:
			add.call("nine_slice_texture", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Texture2D")
			add.call("nine_slice_margins", TYPE_VECTOR4)
			add.call("nine_slice_stretch", TYPE_INT, PROPERTY_HINT_ENUM, STRETCH_NAMES)
			add.call("nine_slice_scale", TYPE_INT, PROPERTY_HINT_RANGE, "1,8,1")
			add.call("image_filter", TYPE_INT, PROPERTY_HINT_ENUM, FILTER_NAMES)
		Source.IMAGE:
			add.call("image_texture", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Texture2D")
			if not is_corner():
				add.call("image_fit", TYPE_INT, PROPERTY_HINT_ENUM, "Stretch,Tile,Tile Fit,Keep Size")
			add.call("image_scale", TYPE_INT, PROPERTY_HINT_RANGE, "1,8,1")
			add.call("image_filter", TYPE_INT, PROPERTY_HINT_ENUM, FILTER_NAMES)
		Source.RESOURCE:
			add.call("resource", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "StyleBox,Texture2D")
			# A flat StyleBox has no pixels to fit, scale or filter.
			if draws_texture() and not is_corner():
				add.call("image_fit", TYPE_INT, PROPERTY_HINT_ENUM, "Stretch,Tile,Tile Fit,Keep Size")
			if draws_texture() or style is StyleBoxTexture:
				add.call("image_scale", TYPE_INT, PROPERTY_HINT_RANGE, "1,8,1")
				add.call("image_filter", TYPE_INT, PROPERTY_HINT_ENUM, FILTER_NAMES)
	# The Padding row draws the mode and the four values together. Only a box
	# holds content to pad: the Panel's base, a name box or a frame.
	if holds_content():
		add.call("padding_mode", TYPE_INT)
	return list


## True for a box that holds content: the Panel's Base Appearance, or a Fill
## layer on the Speaker Name or Dialogue Visual. Its padding is the space
## around that content.
func holds_content() -> bool:
	return is_base or (slot != Slot.PANEL and position == Position.FILL)


func _get(property: StringName) -> Variant:
	var flat := style as StyleBoxFlat
	var nine := style as StyleBoxTexture
	match String(property):
		"appearance":
			return visual_source
		"background":
			return flat.bg_color if flat != null else null
		"border_color":
			return flat.border_color if flat != null else null
		"border_width":
			return flat.border_width_left if flat != null else null
		"corner_radius":
			return flat.corner_radius_top_left if flat != null else null
		"shadow_size":
			return flat.shadow_size if flat != null else null
		"shadow_color":
			return flat.shadow_color if flat != null else null
		"nine_slice_texture":
			return nine.texture if nine != null else null
		"nine_slice_margins":
			if nine == null:
				return null
			return Vector4(nine.texture_margin_left, nine.texture_margin_top, nine.texture_margin_right, nine.texture_margin_bottom)
		"nine_slice_stretch":
			return nine.axis_stretch_horizontal if nine != null else null
		"nine_slice_scale", "image_scale":
			return scale
		"image_texture":
			return texture
		"image_fit":
			return fit
		"image_filter":
			return filter
		"resource":
			return style if style != null else texture
	return null


func _set(property: StringName, value: Variant) -> bool:
	var flat := style as StyleBoxFlat
	var nine := style as StyleBoxTexture
	match String(property):
		"appearance":
			visual_source = value
		"background":
			if flat != null:
				flat.bg_color = value
		"border_color":
			if flat != null:
				flat.border_color = value
		"border_width":
			if flat != null:
				flat.set_border_width_all(value)
		"corner_radius":
			if flat != null:
				flat.set_corner_radius_all(value)
		"shadow_size":
			if flat != null:
				flat.shadow_size = value
				notify_property_list_changed()
		"shadow_color":
			if flat != null:
				flat.shadow_color = value
		"nine_slice_texture":
			if nine != null:
				nine.texture = value
		"nine_slice_margins":
			if nine != null:
				var margins: Vector4 = value
				nine.texture_margin_left = margins.x
				nine.texture_margin_top = margins.y
				nine.texture_margin_right = margins.z
				nine.texture_margin_bottom = margins.w
		"nine_slice_stretch":
			if nine != null:
				nine.axis_stretch_horizontal = value
				nine.axis_stretch_vertical = value
		"nine_slice_scale", "image_scale":
			scale = value
		"image_texture":
			texture = value
		"image_fit":
			fit = value
		"image_filter":
			filter = value
		"resource":
			style = value as StyleBox
			texture = value as Texture2D
			notify_property_list_changed()
		_:
			return false
	emit_changed()
	return true


## True when the source has margins of its own to pad with.
func has_style_margins() -> bool:
	return visual_source == Source.NINE_SLICE or (visual_source == Source.RESOURCE and style != null)


## The margins this box's own style gives, at its scale.
func style_margins() -> Vector4:
	if not has_style_margins() or style == null:
		return Vector4.ZERO
	var drawn := scaled_style(style, scale, not is_pixel_filter(filter))
	return Vector4(drawn.get_margin(SIDE_LEFT), drawn.get_margin(SIDE_TOP), drawn.get_margin(SIDE_RIGHT), drawn.get_margin(SIDE_BOTTOM))


## The space between this box and what it holds.
func effective_padding() -> Vector4:
	if has_style_margins() and padding_mode == PaddingMode.STYLE_MARGINS:
		return style_margins()
	return padding


## What the Padding row shows: whether the source has margins to offer, the
## mode, the custom values and the margins the style itself gives.
func padding_info(_prefix := "") -> Dictionary:
	return {
		"custom_only": not has_style_margins(),
		"mode": padding_mode if has_style_margins() else PaddingMode.CUSTOM,
		"padding": padding,
		"style_margins": style_margins(),
	}


func is_corner() -> bool:
	return position >= Position.TOP_LEFT


func is_edge() -> bool:
	return position >= Position.TOP and position <= Position.RIGHT


func is_vertical_edge() -> bool:
	return position == Position.LEFT or position == Position.RIGHT


## True when this layer draws [member texture] rather than [member style].
func draws_texture() -> bool:
	if visual_source == Source.IMAGE:
		return true
	if visual_source == Source.RESOURCE:
		return style == null and texture != null
	return false


## True when the layer has nothing to draw yet.
func is_empty() -> bool:
	if draws_texture():
		return texture == null
	if style is StyleBoxTexture:
		return (style as StyleBoxTexture).texture == null
	return style == null


## The source's own size at [member scale], or [constant FALLBACK_SIZE]. A
## flat style has no size of its own, and no pixels to scale.
func own_size() -> Vector2:
	var natural := Vector2.ZERO
	if draws_texture():
		if texture != null:
			natural = texture.get_size()
	elif style is StyleBoxTexture and (style as StyleBoxTexture).texture != null:
		natural = style.get_minimum_size().max((style as StyleBoxTexture).texture.get_size())
	elif style != null and style is not StyleBoxFlat:
		natural = style.get_minimum_size()
	if natural.x <= 0.0 or natural.y <= 0.0:
		return FALLBACK_SIZE
	return natural * scale


## The rectangle this layer covers, given its slot's rectangle. A frame around
## the Dialogue Visual keeps its padding between the portrait and itself.
func rect_in(slot_rect: Rect2) -> Rect2:
	if not is_base and slot == Slot.DIALOGUE_VISUAL and position == Position.FILL:
		var pad := effective_padding()
		slot_rect = slot_rect.grow_individual(pad.x, pad.y, pad.z, pad.w)
	var own := own_size()
	var chosen := Vector2(
		size.x if size.x > 0.0 else own.x,
		size.y if size.y > 0.0 else own.y)
	var rect := slot_rect
	match position:
		Position.FILL:
			rect = slot_rect
		Position.TOP, Position.BOTTOM:
			var y := slot_rect.position.y if position == Position.TOP else slot_rect.end.y
			if fit == Fit.KEEP_SIZE and draws_texture():
				rect = Rect2(slot_rect.get_center().x - chosen.x * 0.5, y - chosen.y * 0.5, chosen.x, chosen.y)
			else:
				var length := maxf(0.0, slot_rect.size.x - edge_inset * 2.0)
				rect = Rect2(slot_rect.position.x + edge_inset, y - chosen.y * 0.5, length, chosen.y)
		Position.LEFT, Position.RIGHT:
			var x := slot_rect.position.x if position == Position.LEFT else slot_rect.end.x
			if fit == Fit.KEEP_SIZE and draws_texture():
				rect = Rect2(x - chosen.x * 0.5, slot_rect.get_center().y - chosen.y * 0.5, chosen.x, chosen.y)
			else:
				var length := maxf(0.0, slot_rect.size.y - edge_inset * 2.0)
				rect = Rect2(x - chosen.x * 0.5, slot_rect.position.y + edge_inset, chosen.x, length)
		_:
			var corner := Vector2(
				slot_rect.position.x if position in [Position.TOP_LEFT, Position.BOTTOM_LEFT] else slot_rect.end.x,
				slot_rect.position.y if position in [Position.TOP_LEFT, Position.TOP_RIGHT] else slot_rect.end.y)
			# Centred on the corner point, so an ornament overhangs by default.
			rect = Rect2(corner - chosen * 0.5, chosen)
	rect.position += offset
	return rect


## The area actually painted, including a StyleBox's expand margins.
func painted_rect_in(slot_rect: Rect2) -> Rect2:
	var rect := rect_in(slot_rect)
	if not draws_texture() and style != null:
		var drawn := scaled_style(style, scale, not is_pixel_filter(filter))
		if drawn is StyleBoxTexture or drawn is StyleBoxFlat:
			rect = rect.grow_individual(
				drawn.get("expand_margin_left"), drawn.get("expand_margin_top"),
				drawn.get("expand_margin_right"), drawn.get("expand_margin_bottom"))
	return rect


## Draws this layer onto [param canvas] from inside its [code]_draw()[/code].
func draw(canvas: CanvasItem, slot_rect: Rect2) -> void:
	var rect := rect_in(slot_rect)
	if is_empty():
		if Engine.is_editor_hint():
			_draw_placeholder(canvas, rect)
		return
	if not draws_texture():
		canvas.draw_style_box(scaled_style(style, scale, not is_pixel_filter(filter)), rect)
		return
	_draw_texture(canvas, rect)


func _draw_texture(canvas: CanvasItem, rect: Rect2) -> void:
	var tile_size := texture.get_size() * scale
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return
	if is_corner() or fit == Fit.STRETCH:
		canvas.draw_texture_rect(texture, rect, false)
		return
	if fit == Fit.KEEP_SIZE:
		# An edge's rect is already its size; a fill centres the image in it.
		var kept := rect if position != Position.FILL else Rect2(rect.get_center() - tile_size * 0.5, tile_size)
		canvas.draw_texture_rect(texture, kept, false)
		return
	# Edges tile along their length and stretch across it; a fill tiles both ways.
	var along_x := position == Position.FILL or not is_vertical_edge()
	var along_y := position == Position.FILL or is_vertical_edge()
	if not along_x:
		tile_size.x = rect.size.x
	if not along_y:
		tile_size.y = rect.size.y
	if fit == Fit.TILE_FIT:
		if along_x:
			tile_size.x = rect.size.x / maxf(1.0, roundf(rect.size.x / tile_size.x))
		if along_y:
			tile_size.y = rect.size.y / maxf(1.0, roundf(rect.size.y / tile_size.y))
	_tile(canvas, rect, tile_size)


# Tiles by hand: draw_texture_rect's own tiling would repeat a whole atlas
# instead of an AtlasTexture's region.
func _tile(canvas: CanvasItem, rect: Rect2, tile_size: Vector2) -> void:
	var source_size := texture.get_size()
	var y := rect.position.y
	while y < rect.end.y - 0.01:
		var height := minf(tile_size.y, rect.end.y - y)
		var x := rect.position.x
		while x < rect.end.x - 0.01:
			var width := minf(tile_size.x, rect.end.x - x)
			var part := Vector2(width / tile_size.x, height / tile_size.y)
			canvas.draw_texture_rect_region(texture, Rect2(x, y, width, height),
				Rect2(Vector2.ZERO, source_size * part))
			x += tile_size.x
		y += tile_size.y


func _draw_placeholder(canvas: CanvasItem, rect: Rect2) -> void:
	var area := rect if rect.size.x >= 4.0 and rect.size.y >= 4.0 else Rect2(rect.position, FALLBACK_SIZE)
	canvas.draw_rect(area, Color(0.6, 0.6, 0.6, 0.25), true)
	canvas.draw_rect(area, Color(1.0, 1.0, 1.0, 0.8), false, 1.0)
	canvas.draw_line(area.position, area.end, Color(1.0, 1.0, 1.0, 0.5), 1.0)
	canvas.draw_line(Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y), Color(1.0, 1.0, 1.0, 0.5), 1.0)


func _match_style_to_source() -> void:
	if visual_source == Source.FLAT_STYLE and style is not StyleBoxFlat:
		# Warm and outlined, so a new name box or backing card shows up on
		# both dark and light panels.
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.45, 0.2, 0.12, 0.95)
		flat.border_color = Color(0.95, 0.75, 0.4)
		flat.set_border_width_all(1)
		flat.set_corner_radius_all(3)
		style = flat
	elif visual_source == Source.NINE_SLICE and style is not StyleBoxTexture:
		style = StyleBoxTexture.new()


#region Pixel scale

## True when [param texture_filter] samples nearest pixels, following the
## project setting for [constant CanvasItem.TEXTURE_FILTER_PARENT_NODE].
static func is_pixel_filter(texture_filter: CanvasItem.TextureFilter) -> bool:
	if texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		return int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 1)) == 0
	return texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST or texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

static var _scaled_cache := {}


## [param original] drawn at a whole-number [param factor]. A [StyleBoxTexture]
## gets a copy whose texture and margins are scaled with nearest-neighbour
## sampling, so a 16 px pixel-art frame stays crisp at ×3. Anything else, or a
## texture whose pixels cannot be read, is returned unchanged.
static func scaled_style(original: StyleBox, factor: int, smooth := false) -> StyleBox:
	if factor <= 1 or original is not StyleBoxTexture:
		return original
	var textured := original as StyleBoxTexture
	if textured.texture == null:
		return original
	var key := "%d:%d:%d:%s" % [textured.get_instance_id(), factor, textured.texture.get_instance_id(), smooth]
	if _scaled_cache.has(key):
		return _scaled_cache[key]
	var source := textured.texture.get_image()
	if source == null:
		return original
	# In the editor get_image() can hand back the texture's own cached image;
	# resizing that in place would grow the frame on every call.
	var image := source.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	if textured.region_rect.has_area():
		image = image.get_region(Rect2i(textured.region_rect))
	image.resize(image.get_width() * factor, image.get_height() * factor,
		Image.INTERPOLATE_BILINEAR if smooth else Image.INTERPOLATE_NEAREST)
	var copy := textured.duplicate() as StyleBoxTexture
	copy.texture = ImageTexture.create_from_image(image)
	copy.region_rect = Rect2()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		copy.set_texture_margin(side, textured.get_texture_margin(side) * factor)
		copy.set_expand_margin(side, textured.get_expand_margin(side) * factor)
		# A negative content margin means "use the texture margin": leave it.
		if textured.get_content_margin(side) >= 0.0:
			copy.set_content_margin(side, textured.get_content_margin(side) * factor)
	if _scaled_cache.size() > 64:
		_scaled_cache.clear()
	_scaled_cache[key] = copy
	# Any edit to the style or a reimport of its image makes the copy stale.
	var forget := func() -> void: _scaled_cache.erase(key)
	textured.changed.connect(forget, CONNECT_ONE_SHOT)
	textured.texture.changed.connect(forget, CONNECT_ONE_SHOT)
	return copy


#endregion
