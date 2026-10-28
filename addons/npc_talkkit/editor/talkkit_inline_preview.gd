@tool
## Renders a line with the runtime renderer and TalkContext inside an editor
## SubViewport, so custom renderers and template styling show while authoring.
extends TextureRect

## Emitted after the preview rebuilt its renderer.
signal refreshed

var component: NPCTalkKit
var conversation: TalkConversation
var line: TalkLine
## When true, the line plays with typewriter, transitions and voice; when
## false, it is shown in its finished state.
var animate := false

var _viewport: SubViewport
var _stand_in: Node2D
var _renderer: Node
var _generation := 0
# Another preview this one shows larger, sharing its renderer.
var _mirror: TextureRect
# The part of the game screen shown: the box and what it draws past its edges.
var _atlas: AtlasTexture


func _ready() -> void:
	custom_minimum_size = Vector2(220, 170)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _mirror != null:
		texture = _mirror.texture
		return
	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The game's own screen, scaled down into the pane, so text wraps and the
	# box sits exactly as it will in the game.
	_viewport.size = game_screen_size()
	add_child(_viewport)
	# Stand-in for the NPC, centred near the bottom so a following box fits above.
	_stand_in = Node2D.new()
	_stand_in.name = "StandIn"
	_stand_in.position = Vector2(_viewport.size.x * 0.5, _viewport.size.y - 30.0)
	_viewport.add_child(_stand_in)
	# Laid out on the whole game screen, shown cropped to the box so it reads.
	_atlas = AtlasTexture.new()
	_atlas.atlas = _viewport.get_texture()
	_atlas.region = Rect2(Vector2.ZERO, _viewport.size)
	texture = _atlas
	set_process(true)
	refresh()


func set_preview(
	new_component: NPCTalkKit,
	new_conversation: TalkConversation,
	new_line: TalkLine,
) -> void:
	component = new_component
	conversation = new_conversation
	line = new_line
	if is_node_ready():
		refresh()


func set_animate(value: bool) -> void:
	if value == animate:
		return
	animate = value
	# A frozen renderer stops processing, so switching modes needs a fresh one.
	_clear_renderer()
	if is_node_ready():
		refresh()


func refresh() -> void:
	_generation += 1
	var generation := _generation
	visible = component != null and line != null
	if not visible or _viewport == null:
		_clear_renderer()
		return
	var template := component.resolve_dialogue_box(line, conversation)
	var id := String(component._renderer_id(template))
	# While playing, reuse the box on screen, as the runtime does.
	if animate and is_instance_valid(_renderer) and _renderer.get_meta("talkkit_renderer", "") == id:
		_renderer.call("setup", _preview_context())
		_renderer.call("show_line", line)
		return
	_clear_renderer()
	var scene: PackedScene = component._renderer_scene(template)
	if scene == null:
		return
	_renderer = scene.instantiate()
	_renderer.set_meta("talkkit_renderer", id)
	_viewport.add_child(_renderer)
	_renderer.call("setup", _preview_context())
	_renderer.call("show_line", line)
	_renderer.visible = true
	if not animate:
		# Frozen on the next frame, after setup() has started its opening tween.
		call_deferred("_freeze", generation)
	else:
		refreshed.emit()


## Shows [param source]'s preview instead of rendering one, for a larger view
## of the same box. Call before adding to the tree.
func mirror(source: TextureRect) -> void:
	_mirror = source


## The renderer drawing the preview, or null.
func get_renderer() -> Node:
	if _mirror != null:
		return _mirror.get_renderer() if is_instance_valid(_mirror) else null
	return _renderer if is_instance_valid(_renderer) else null


## The preview viewport's size in pixels.
func viewport_size() -> Vector2:
	if _mirror != null and is_instance_valid(_mirror):
		return _mirror.viewport_size()
	return Vector2(_viewport.size) if _viewport != null else Vector2(game_screen_size())


## The project's base screen size, which the game lays the box out in.
static func game_screen_size() -> Vector2i:
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	return Vector2i(maxi(width, 320), maxi(height, 180))


## The part of the preview viewport this control shows: the box with room
## around it, or the whole screen when there is no box.
func shown_region() -> Rect2:
	if _mirror != null and is_instance_valid(_mirror):
		return _mirror.shown_region()
	return _atlas.region if _atlas != null else Rect2(Vector2.ZERO, viewport_size())


## Maps a rectangle in the preview viewport to this control's coordinates. The
## shown region is scaled to fit and centred, keeping its aspect.
func viewport_to_local(rect: Rect2) -> Rect2:
	var region := shown_region()
	var fit := minf(size.x / region.size.x, size.y / region.size.y)
	var origin := (size - region.size * fit) * 0.5
	return Rect2(origin + (rect.position - region.position) * fit, rect.size * fit)


func _process(_delta: float) -> void:
	if _atlas == null:
		return
	var wanted := _box_region()
	if not wanted.is_equal_approx(_atlas.region):
		_atlas.region = wanted


# The box, its overhang and its tail, with a margin, within the screen.
func _box_region() -> Rect2:
	var screen := Rect2(Vector2.ZERO, viewport_size())
	var renderer := get_renderer() as TalkBoxRenderer
	if renderer == null:
		return screen
	var box := renderer.get_box_control()
	if box == null or not box.is_visible_in_tree():
		return screen
	var bleed := renderer.layer_bleed()
	var area := box.get_global_rect().grow_individual(bleed.x, bleed.y, bleed.z, bleed.w)
	var tail: Variant = renderer.slot_rects().get("tail")
	if tail is Rect2:
		area = area.merge(tail)
	area = area.grow(24.0).intersection(screen)
	return area if area.has_area() else screen


## The runtime context, with a following placement retargeted at the stand-in:
## the real target lives in the edited scene, outside this viewport.
func _preview_context() -> TalkContext:
	var context := component.build_context(line, conversation)
	if context.anchor != null and context.anchor.mode == TalkAnchor.Mode.NODE_FOLLOW:
		# A copy, so the authored placement is not modified.
		var anchor := context.anchor.duplicate() as TalkAnchor
		anchor.follow_target = NodePath()
		context.anchor = anchor
		context.target = _stand_in
	return context


func _freeze(generation: int) -> void:
	if generation != _generation or not is_instance_valid(_renderer):
		return
	if _renderer.has_method("freeze"):
		_renderer.call("freeze")
	if _renderer.has_method("get_text_label"):
		var label := _renderer.call("get_text_label") as RichTextLabel
		if label != null:
			label.visible_characters = -1
	refreshed.emit()


func _clear_renderer() -> void:
	if not is_instance_valid(_renderer):
		_renderer = null
		return
	var parent := _renderer.get_parent()
	if parent != null:
		parent.remove_child(_renderer)
	_renderer.queue_free()
	_renderer = null


func _exit_tree() -> void:
	_generation += 1
	_clear_renderer()
