@tool
## Base class for dialogue box renderers, including the built-in box.
##
## Implements the typewriter, voice blips, input, styling, anchoring,
## transitions and the speech lifecycle. A custom renderer extends this and
## overrides the [code]get_*[/code] methods to return its own controls.
##
## Use it for layouts a [TalkBoxTemplate] cannot describe; for visual changes,
## a template is enough.
@icon("res://addons/npc_talkkit/icons/talk_box_renderer.svg")
class_name TalkBoxRenderer
extends CanvasLayer

## The player asked to move past a fully shown line.
signal advance_requested
## The current line finished typing.
signal finished
## The close transition finished; the box is about to be freed.
signal closed

## The box's own lifecycle state, separate from the conversation state.
enum Phase { HIDDEN, OPENING, SHOWN, CHANGING, CLOSING }
## A line started typing.
signal speech_started(line: TalkLine)
## Typing progress of [param line], from 0.0 to 1.0.
signal speech_progress(line: TalkLine, normalized_progress: float)
## A line finished typing.
signal speech_finished(line: TalkLine)

## Placement used when the context supplies no anchor.
@export var default_anchor: TalkAnchor

const LayerView := preload("res://addons/npc_talkkit/box/talk_box_layer_view.gd")


var context: TalkContext
var current_line: TalkLine
var last_anchor: TalkAnchorResult
var phase := Phase.HIDDEN

## Transition channels, combined with the anchored placement every frame.
## A [TalkTransition] animates these instead of the box control.
var transition_alpha := 1.0
var transition_offset := Vector2.ZERO
var transition_scale := 1.0

var _implicit_template: TalkBoxTemplate
var _transition_tween: Tween
var _pending_line: TalkLine
var _visible_characters := 0.0
var _last_blip_msec := 0
var _typing := false
var _audio_player: AudioStreamPlayer
# Seconds since the current line appeared; samples an animated visual.
var _visual_elapsed := 0.0
# Drives the continue indicator's idle motion.
var _indicator_elapsed := 0.0
var _layer_views: Array = []
# True once a line has been shown since the box opened.
var _line_shown := false


func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "VoiceBlipPlayer"
	add_child(_audio_player)
	# Keep processing on so a following box tracks its target after typing ends.
	set_process(true)


## Applies a resolved [TalkContext]: template, speaker and placement. Opens the
## box if it is hidden.
func setup(new_context: TalkContext) -> void:
	context = new_context
	_apply_speaker_visibility()
	apply_template()
	var anchor := effective_anchor()
	set_physics_process(anchor != null and anchor.wants_physics_frame())
	apply_anchor()
	if phase == Phase.HIDDEN:
		open()


## Plays the opening transition. Can be awaited.
func open() -> void:
	if phase == Phase.SHOWN or phase == Phase.OPENING:
		return
	phase = Phase.OPENING
	_line_shown = false
	await effective_template().transition_for("open").play_in(self)
	if phase == Phase.OPENING:
		phase = Phase.SHOWN
		_start_pending_line()


## Cancels an unfinished close and shows the box at rest.
func reopen() -> void:
	_kill_transition()
	phase = Phase.SHOWN
	transition_alpha = 1.0
	transition_offset = Vector2.ZERO
	transition_scale = 1.0


## Shows [param line] and starts typing it, after any line transition.
func show_line(line: TalkLine) -> void:
	current_line = line
	var text_label := get_text_label()
	if text_label == null:
		push_error("TalkKit renderer is missing a text label.")
		return
	text_label.text = line.text
	# Hidden until typing starts, so a line transition never shows it whole.
	if _speed_for(line) > 0.0:
		text_label.visible_characters = 0
	var name_label := get_name_label()
	if name_label != null:
		name_label.text = context.display_name() if context != null else ""
	_visual_elapsed = 0.0
	_apply_visual()
	_apply_speaker_visibility()
	var line_change := effective_template().transition_for("line")
	# The first line after opening arrives with the open transition, not a
	# line change.
	if phase == Phase.SHOWN and _line_shown and not line_change.is_instant():
		phase = Phase.CHANGING
		_pending_line = line
		await line_change.play_in(self)
		if phase != Phase.CHANGING:
			return
		phase = Phase.SHOWN
		_pending_line = null
	_begin_typing(line)


# Called once any transition has finished.
func _begin_typing(line: TalkLine) -> void:
	var text_label := get_text_label()
	if text_label == null:
		return
	_line_shown = true
	_typing = _speed_for(line) > 0.0 and visible_length() > 0
	_visible_characters = 0.0 if _typing else float(visible_length())
	text_label.visible_characters = 0 if _typing else -1
	_update_indicator(0.0)
	speech_started.emit(line)
	if not _typing:
		speech_progress.emit(line, 1.0)
		speech_finished.emit(line)
		finished.emit()


## Reveals the rest of the current line at once, or skips a running transition.
func finish_line() -> void:
	if phase == Phase.CHANGING:
		_snap_transition()
		return
	if phase == Phase.OPENING:
		_snap_transition()
	if current_line == null:
		return
	var text_label := get_text_label()
	if text_label != null:
		text_label.visible_characters = -1
	if _typing:
		_typing = false
		_update_indicator(0.0)
		speech_progress.emit(current_line, 1.0)
		speech_finished.emit(current_line)
		finished.emit()


## Plays the closing transition, then frees the box.
func close() -> void:
	if phase == Phase.CLOSING:
		return
	phase = Phase.CLOSING
	_typing = false
	_pending_line = null
	await effective_template().transition_for("close").play_out(self)
	if phase != Phase.CLOSING:
		# Reopened while closing.
		return
	set_process(false)
	closed.emit()
	queue_free()


## True while the line is typing or a line transition is running.
func is_typing() -> bool:
	return _typing or phase == Phase.CHANGING


## Finishes the line if it is typing; otherwise emits [signal advance_requested].
func request_advance() -> void:
	if _typing:
		finish_line()
	else:
		advance_requested.emit()


## Override: the [RichTextLabel] that shows the line text. Required.
func get_text_label() -> RichTextLabel:
	return null


## Override: the label for the speaker's name, or null.
func get_name_label() -> Label:
	return null


## Override: where the speaker's visual is drawn, or null.
func get_visual_rect() -> TextureRect:
	return null


## Number of visible characters to reveal, excluding BBCode tags.
func visible_length() -> int:
	var text_label := get_text_label()
	return text_label.get_total_character_count() if text_label != null else 0


## The line text without BBCode tags.
func visible_text() -> String:
	var text_label := get_text_label()
	return text_label.get_parsed_text() if text_label != null else ""


## Override: the "press to continue" glyph, or null.
func get_continue_label() -> Label:
	return null


## Override: the image shown when the template's indicator is an image, or null.
func get_continue_image() -> TextureRect:
	return null


## Override: the control holding the continue indicator. It is shown only when
## the player can advance, and carries the idle motion. Defaults to the glyph.
func get_continue_indicator() -> Control:
	return get_continue_label()


## Override: the tail that points at the speaker, or null.
func get_tail() -> Polygon2D:
	return null


## Override: the container holding the visual and the text, so the template
## can place the visual on either side. May be null.
func get_content_container() -> BoxContainer:
	return null


#region Styling

## The template resolved for the current line, or a default template.
func effective_template() -> TalkBoxTemplate:
	if context != null and context.template != null:
		return context.template
	if _implicit_template == null:
		_implicit_template = TalkBoxTemplate.new()
	return _implicit_template


## Applies [method effective_template] to this box's parts, then its layers.
func apply_template() -> void:
	var name_label := get_name_label()
	if name_label != null:
		# Lets a long name give way on a narrow screen instead of widening the box.
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effective_template().apply_to(
		get_box_control(),
		get_text_label(),
		get_name_label(),
		get_visual_rect(),
		get_continue_label(),
		get_tail(),
		get_content_container(),
		get_continue_image())
	apply_layers()
	_update_indicator(0.0)

#endregion


#region Layers

## The control a layer on [param slot] decorates, or null when this renderer
## has no such part.
func get_slot_control(slot: TalkBoxLayer.Slot) -> Control:
	match slot:
		TalkBoxLayer.Slot.PANEL:
			return get_box_control()
		TalkBoxLayer.Slot.SPEAKER_NAME:
			return get_name_label()
		TalkBoxLayer.Slot.DIALOGUE_VISUAL:
			return get_visual_rect()
	return null


## The layer slots this renderer has a control for. Layers on any other slot
## are skipped.
func exposed_slots() -> Array[TalkBoxLayer.Slot]:
	var slots: Array[TalkBoxLayer.Slot] = []
	for slot in [TalkBoxLayer.Slot.PANEL, TalkBoxLayer.Slot.SPEAKER_NAME, TalkBoxLayer.Slot.DIALOGUE_VISUAL]:
		if get_slot_control(slot) != null:
			slots.append(slot)
	return slots


## Rebuilds the drawn layers from the template's [member TalkBoxTemplate.layers].
func apply_layers() -> void:
	for view in _layer_views:
		if is_instance_valid(view):
			view.get_parent().remove_child(view)
			view.queue_free()
	_layer_views.clear()
	var template := effective_template()
	# A textured Base Appearance draws like a layer, under everything else, so
	# its Image Filter applies.
	var drawn: Array = [template.base] if template.base_draws_in_view() else []
	drawn.append_array(template.layers)
	for entry in drawn:
		var layer := entry as TalkBoxLayer
		if layer == null or not layer.enabled:
			continue
		var host := get_slot_control(layer.slot)
		if host == null:
			continue
		var behind := layer.depth == TalkBoxLayer.Depth.BEHIND
		var view := LayerView.new()
		view.setup(layer, behind and layer.slot != TalkBoxLayer.Slot.PANEL)
		# Internal children are drawn in order: front ones before the normal
		# children, back ones after. Containers ignore them for layout.
		host.add_child(view, false, Node.INTERNAL_MODE_FRONT if behind else Node.INTERNAL_MODE_BACK)
		if behind:
			host.move_child(view, _behind_count(host, view))
		_layer_views.append(view)
	_pad_name_for_name_box(template)


## The view drawing [param layer], or null when it is disabled or not shown.
func layer_view(layer: TalkBoxLayer) -> Control:
	for view in _layer_views:
		if is_instance_valid(view) and view.layer == layer:
			return view
	return null


## The area [param layer] paints, in this renderer's canvas coordinates. Empty
## when the layer is not drawn.
func layer_rect(layer: TalkBoxLayer) -> Rect2:
	var view = layer_view(layer)
	if view == null or not view.is_visible_in_tree():
		return Rect2()
	return view.get_global_transform() * view.painted_rect()


## Each part of the box in this renderer's canvas coordinates, keyed by
## "panel", "name", "visual", "text", "continue" and "tail". Parts that are
## missing or hidden are left out.
func slot_rects() -> Dictionary:
	var rects := {}
	var parts := {
		"panel": get_box_control(),
		"name": get_name_label(),
		"visual": get_visual_rect(),
		"text": get_text_label(),
		"continue": get_continue_indicator(),
	}
	for key in parts:
		var control: Control = parts[key]
		if control != null and control.is_visible_in_tree():
			rects[key] = control.get_global_rect()
	var tail := get_tail()
	if tail != null and tail.is_visible_in_tree() and tail.polygon.size() >= 3:
		var points := tail.get_global_transform() * tail.polygon
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		rects["tail"] = bounds
	return rects


# The number of front internal layer views placed before [param view].
func _behind_count(host: Node, view: Node) -> int:
	var count := 0
	for child in host.get_children(true):
		if child == view:
			break
		if child in _layer_views:
			count += 1
	return count


# A name box needs room around the name: its padding gives it, as the
# Panel's padding does for the box's content.
func _pad_name_for_name_box(template: TalkBoxTemplate) -> void:
	var label := get_name_label()
	if label == null:
		return
	for layer in template.layers_for(TalkBoxLayer.Slot.SPEAKER_NAME):
		if layer.enabled and layer.position == TalkBoxLayer.Position.FILL:
			var margins := layer.effective_padding()
			var spacing := StyleBoxEmpty.new()
			for side in 4:
				spacing.set_content_margin(side, margins[side])
			label.add_theme_stylebox_override("normal", spacing)
			return
	label.remove_theme_stylebox_override("normal")


## How far the drawn layers reach past the box control: left, top, right,
## bottom, in the box's own units. Placement keeps that much room on screen.
func layer_bleed() -> Vector4:
	var box := get_box_control()
	if box == null:
		return Vector4.ZERO
	var bounds := Rect2(Vector2.ZERO, box.size)
	for rect in _bleed_rects():
		bounds = bounds.merge(rect)
	return Vector4(
		maxf(0.0, -bounds.position.x), maxf(0.0, -bounds.position.y),
		maxf(0.0, bounds.end.x - box.size.x), maxf(0.0, bounds.end.y - box.size.y))


# True when [param control] is shown once the box is: hiding the box itself,
# as placement does while a target is off screen, does not count.
func _shown_within(control: Control, box: Control) -> bool:
	var node: Node = control
	while node != null and node != box:
		if node is CanvasItem and not (node as CanvasItem).visible:
			return false
		node = node.get_parent()
	return node == box


## Override to add parts drawn outside the box control, in its coordinates.
func _bleed_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var box := get_box_control()
	for view in _layer_views:
		if not is_instance_valid(view) or not _shown_within(view, box):
			continue
		var to_box: Transform2D = box.get_global_transform().affine_inverse() * view.get_global_transform()
		rects.append(to_box * view.painted_rect())
	return rects

#endregion


func _process(delta: float) -> void:
	if not is_physics_processing():
		apply_anchor()
	_advance_visual(delta)
	_advance_typewriter(delta)
	_update_indicator(delta)


# Used when the anchor needs the physics space for occlusion.
func _physics_process(_delta: float) -> void:
	apply_anchor()


#region Transition plumbing

## Stops typing and transitions and holds the box at rest, fully shown.
func freeze() -> void:
	_kill_transition()
	_typing = false
	_pending_line = null
	phase = Phase.SHOWN
	transition_alpha = 1.0
	transition_offset = Vector2.ZERO
	transition_scale = 1.0
	apply_anchor()
	_update_indicator(0.0)
	set_process(false)
	set_physics_process(false)


func _track_transition(tween: Tween) -> void:
	_kill_transition()
	_transition_tween = tween


func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _snap_transition() -> void:
	_kill_transition()
	transition_alpha = 1.0
	transition_offset = Vector2.ZERO
	transition_scale = 1.0
	phase = Phase.SHOWN
	_start_pending_line()


func _start_pending_line() -> void:
	if _pending_line == null:
		return
	var line := _pending_line
	_pending_line = null
	_begin_typing(line)

#endregion


#region Anchoring

## Override: the control that anchoring and transitions move. Return null to
## position the box yourself.
func get_box_control() -> Control:
	return null


## The context's anchor, or [member default_anchor].
func effective_anchor() -> TalkAnchor:
	if context != null and context.anchor != null:
		return context.anchor
	return default_anchor


## Resolves the placement for this frame and applies it to the box control.
func apply_anchor() -> void:
	var box := get_box_control()
	var anchor := effective_anchor()
	if box == null or anchor == null or not box.is_inside_tree():
		return
	# The target may be freed mid-conversation; only is_instance_valid
	# detects a freed object.
	var target: Node = context.target if context != null else null
	if not is_instance_valid(target):
		target = null
	var view := box.get_viewport().get_visible_rect().size
	# Layers that overhang the box need room on screen too, so placement works
	# on the box plus its overhang. Measured on last frame's settled layout,
	# before the box is resized below.
	var bleed := layer_bleed()
	var bleed_size := Vector2(bleed.x + bleed.z, bleed.y + bleed.w)
	# A box scaled with distance takes more or less room per unit.
	var distance_scale := last_anchor.scale if last_anchor != null and last_anchor.visible else 1.0
	var room := anchor.room(view) / maxf(distance_scale, 0.001) - bleed_size
	var forced := anchor.forced_size(view)
	if anchor.stretches(view):
		forced.x = room.x
	_fit_box(box, forced, room.max(Vector2.ZERO))
	var result := anchor.resolve(self, box.size + bleed_size, target)
	last_anchor = result
	box.visible = result.visible
	if not result.visible:
		return
	# Named box_scale: CanvasLayer already has a `scale` property.
	var box_scale := result.scale * transition_scale
	# Scale from the centre only while a transition scales the box.
	box.pivot_offset = box.size * 0.5 if not is_equal_approx(transition_scale, 1.0) else Vector2.ZERO
	box.scale = Vector2.ONE * box_scale
	box.position = result.position + Vector2(bleed.x, bleed.y) * result.scale + transition_offset
	box.modulate.a = transition_alpha
	_on_anchored(result)


## Width the text wraps at when nothing else sets the box's width: no forced
## size, and no minimum text width on the template.
const WRAP_WIDTH := 440.0


# Sizes the box for this frame. The width is the forced one, or what the text
# and name need up to WRAP_WIDTH; never wider than [param room]. The height is
# what the content needs at that width, at least the forced height.
func _fit_box(box: Control, forced: Vector2, room: Vector2) -> void:
	var template := effective_template()
	var text := get_text_label()
	var column := text.get_parent() as Control if text != null else null
	if text != null:
		# The template's minimum text width gives way before the box would
		# leave the screen.
		_set_min_width(text, template.text_min_size.x, box)
	var natural := box.get_combined_minimum_size()
	if text != null and room.x > 0.0 and natural.x > room.x:
		_set_min_width(text, maxf(0.0, template.text_min_size.x - (natural.x - room.x)), box)
		natural = box.get_combined_minimum_size()
	# What the box adds around the text's column: padding, the visual, spacing.
	var chrome := natural.x - column.get_combined_minimum_size().x if column != null and column != box else 0.0

	var width := forced.x
	if width <= 0.0:
		width = maxf(natural.x, _name_need(box, column, chrome))
		if text != null and text.autowrap_mode != TextServer.AUTOWRAP_OFF and text.custom_minimum_size.x <= 0.0:
			var wrap := WRAP_WIDTH if room.x <= 0.0 else minf(WRAP_WIDTH, room.x - chrome)
			text.size.x = maxf(1.0, wrap)
			var margins := text.get_theme_stylebox("normal").get_minimum_size().x
			width = maxf(width, chrome + ceilf(text.get_content_width() + margins))
	if room.x > 0.0:
		width = minf(width, room.x)
	width = maxf(width, natural.x)

	var height := natural.y
	if text != null:
		# Wrapped text is as tall as its width makes it; measure it at the width
		# it is about to get, so placement never uses last frame's height.
		text.size.x = maxf(1.0, width - chrome)
		_refresh_minimum_size(text, box)
		height = box.get_combined_minimum_size().y
	height = maxf(height, forced.y)
	box.size = Vector2(width, height)


# The width the speaker's name needs to show whole.
func _name_need(box: Control, column: Control, chrome: float) -> float:
	var label := get_name_label()
	if label == null or not label.visible or label.text.is_empty():
		return 0.0
	var name_width := name_width()
	if label.get_parent() == column:
		return chrome + name_width
	# A name on the Panel's edge sits within the Panel's padding.
	var padding := effective_template().effective_padding()
	return name_width + padding.x + padding.z + absf(effective_template().name_offset.x)


## The width the speaker's name takes shown whole, padding included. The name
## label itself may be narrower: it trims with an ellipsis when the box has
## no more room.
func name_width() -> float:
	var label := get_name_label()
	if label == null or label.text.is_empty():
		return 0.0
	var font := label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		label.get_theme_font_size("font_size")).x if font != null else 0.0
	return ceilf(width + label.get_theme_stylebox("normal").get_minimum_size().x)


func _set_min_width(control: Control, width: float, box: Control) -> void:
	if is_equal_approx(control.custom_minimum_size.x, width):
		return
	control.custom_minimum_size.x = width
	_refresh_minimum_size(control, box)


# Godot refreshes a container's minimum size a frame late; refresh the chain
# from [param from] up to [param to] now, so this frame's layout uses it.
func _refresh_minimum_size(from: Control, to: Control) -> void:
	var node: Node = from
	while node is Control:
		(node as Control).update_minimum_size()
		if node == to:
			break
		node = node.get_parent()


## Override: called after each placement, for parts that follow the anchor,
## such as a tail.
func _on_anchored(_result: TalkAnchorResult) -> void:
	pass

#endregion


## True when the player can move on: the line is fully shown and no
## transition is running.
func can_advance() -> bool:
	return current_line != null and not _typing and phase == Phase.SHOWN


# Shows the continue indicator only when the player can advance, and plays
# the template's idle motion. Its room is kept while it is hidden, so the box
# does not change size when a line finishes typing.
func _update_indicator(delta: float) -> void:
	var indicator := get_continue_indicator()
	if indicator == null:
		return
	var template := effective_template()
	# The glyph and the image are the indicator when no container holds them;
	# the template has already shown the one its look uses.
	var parts: Array[Control] = []
	if indicator == get_continue_label() or indicator == get_continue_image():
		for part in [get_continue_label(), get_continue_image()]:
			if part != null:
				parts.append(part)
	else:
		indicator.visible = template.continue_shown
		parts.append(indicator)
	var ready := template.continue_shown and can_advance()
	if not ready:
		_indicator_elapsed = 0.0
		for part in parts:
			part.modulate.a = 0.0
		return
	_indicator_elapsed += delta
	var bounce := 0
	if template.continue_motion == TalkBoxTemplate.IndicatorMotion.BOUNCE:
		bounce = int(roundf((sin(_indicator_elapsed * TAU * 1.2) + 1.0) * 1.5))
	if indicator is MarginContainer:
		indicator.add_theme_constant_override("margin_top", bounce)
		indicator.add_theme_constant_override("margin_bottom", 3 - bounce if template.continue_motion == TalkBoxTemplate.IndicatorMotion.BOUNCE else 0)
	var blink := template.continue_motion == TalkBoxTemplate.IndicatorMotion.BLINK
	for part in parts:
		part.modulate.a = 0.0 if blink and fmod(_indicator_elapsed, 1.0) > 0.6 else 1.0


func _advance_typewriter(delta: float) -> void:
	if not _typing or current_line == null:
		return
	var text_label := get_text_label()
	if text_label == null:
		finish_line()
		return
	var total := visible_length()
	var previous := int(_visible_characters)
	_visible_characters = minf(_visible_characters + _speed_for(current_line) * delta, total)
	var current := int(_visible_characters)
	text_label.visible_characters = current
	if current > previous:
		_try_voice_blip(current - 1)
	var progress := 1.0 if total == 0 else _visible_characters / float(total)
	speech_progress.emit(current_line, clampf(progress, 0.0, 1.0))
	if current >= total:
		finish_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		request_advance()
		get_viewport().set_input_as_handled()


# Resolved by NPCTalkKit into context.typewriter_speed.
func _speed_for(_line: TalkLine) -> float:
	return context.typewriter_speed if context != null else 40.0


func _advance_visual(delta: float) -> void:
	if context == null or context.active == null or context.active.visual == null:
		return
	if context.active.visual.sprite_frames == null:
		return
	_visual_elapsed += delta
	_apply_visual()


func _apply_visual() -> void:
	var rect := get_visual_rect()
	if rect == null:
		return
	var texture := context.visual_texture(_visual_elapsed) if context != null else null
	if rect.texture != texture:
		rect.texture = texture
	if context != null and context.active != null and context.active.visual != null:
		rect.flip_h = context.active.visual.flip_h


func _apply_speaker_visibility() -> void:
	var template := effective_template()
	var name_label := get_name_label()
	if name_label != null:
		name_label.visible = template.name_shown and not name_label.text.is_empty()
	var rect := get_visual_rect()
	if rect != null:
		rect.visible = template.visual_shown and rect.texture != null


func _try_voice_blip(character_index: int) -> void:
	var voice := context.voice_speaker() if context != null else null
	if voice == null or voice.voice_blip == null:
		return
	# Index into the parsed text so BBCode tags never blip.
	var text := visible_text()
	if character_index < 0 or character_index >= text.length():
		return
	var character := text.substr(character_index, 1)
	if character.strip_edges().is_empty() or character in [".", ",", "!", "?", ":", ";", "-", "…"]:
		return
	var now := Time.get_ticks_msec()
	if now - _last_blip_msec < int(voice.voice_blip_interval * 1000.0):
		return
	_last_blip_msec = now
	var pitch := voice.normalized_pitch_range()
	_audio_player.stream = voice.voice_blip
	_audio_player.pitch_scale = randf_range(pitch.x, pitch.y)
	_audio_player.play()
