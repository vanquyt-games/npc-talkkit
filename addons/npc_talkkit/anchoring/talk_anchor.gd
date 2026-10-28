@tool
## Where a dialogue box sits: pinned to the screen, or following a node.
##
## Placement is independent of the box style, so any template can use any
## placement. Every mode resolves through [method resolve]; override it in a
## subclass for a custom position provider.
@icon("res://addons/npc_talkkit/icons/talk_anchor.svg")
class_name TalkAnchor
extends Resource

enum Mode {
	SCREEN,       ## Pinned to the viewport.
	NODE_FOLLOW,  ## Tracks a Node2D or Node3D.
}

enum Spot {
	TOP_LEFT, TOP, TOP_RIGHT,
	LEFT, CENTER, RIGHT,
	BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT,
	ABSOLUTE,     ## Use screen_position verbatim.
}

enum Offscreen {
	CLAMP,  ## Keep the box inside the viewport.
	HIDE,   ## Hide the box while the target is off screen; keep it inside the viewport otherwise.
	FREE,   ## Let it travel off screen.
}

@export var mode: Mode = Mode.SCREEN

@export_group("Screen")
@export var screen_spot: Spot = Spot.BOTTOM
@export var screen_margin := Vector2(32.0, 32.0)
## Used only when screen_spot is ABSOLUTE.
@export var screen_position := Vector2.ZERO
## Fill the viewport width, minus the horizontal margin.
@export var stretch_horizontal := false
## Force a box size. Zero on an axis keeps the box's natural size. A box
## whose content needs more room grows past it rather than overflowing.
@export var box_size := Vector2.ZERO

@export_group("Follow")
## Node to follow, relative to the NPCTalkKit node. Empty follows the
## conversation target.
@export var follow_target := NodePath()
## Screen-space nudge, applied after projection.
@export var follow_offset := Vector2(0.0, -96.0)
## Which part of the box lands on the target. (0.5, 1) puts the box above it,
## (0.5, 0) below, (1, 0.5) to its left.
@export var pivot := Vector2(0.5, 1.0)
@export var when_offscreen: Offscreen = Offscreen.CLAMP
@export var viewport_margin := 12.0

@export_group("Follow 3D")
## World-space offset applied before projection, such as head height. Stays on
## the character at any camera distance, unlike [member follow_offset].
@export var follow_offset_3d := Vector3(0.0, 2.0, 0.0)
## Hide past this distance. Zero means no limit.
@export var max_distance := 0.0
## Scale the box with camera distance. Off keeps a constant on-screen size.
@export var scale_with_distance := false
@export var reference_distance := 6.0
@export_range(0.05, 4.0, 0.05) var min_scale := 0.6
@export_range(0.05, 4.0, 0.05) var max_scale := 1.4
## Hide the box when a raycast from the camera hits something before the
## target. Costs one raycast per frame.
@export var hide_when_occluded := false
@export_flags_3d_physics var occlusion_mask := 1


# Shows only the settings that apply to the chosen mode.
func _validate_property(property: Dictionary) -> void:
	var screen_only := [
		"screen_spot", "screen_margin", "screen_position", "stretch_horizontal",
	]
	# Applied by _place() to any point-anchored placement.
	var point_placement := ["follow_offset", "pivot", "when_offscreen", "viewport_margin"]
	var follow_only := [
		"follow_target",
		"follow_offset_3d", "max_distance", "scale_with_distance", "reference_distance",
		"min_scale", "max_scale", "hide_when_occluded", "occlusion_mask",
	]
	var name := String(property.name)
	var hide := false
	if name in screen_only:
		hide = mode != Mode.SCREEN
	elif name in point_placement:
		hide = mode == Mode.SCREEN
	elif name in follow_only:
		hide = mode != Mode.NODE_FOLLOW

	if name == "screen_position" and screen_spot != Spot.ABSOLUTE:
		hide = true
	if name in ["reference_distance", "min_scale", "max_scale"] and not scale_with_distance:
		hide = true
	if name == "occlusion_mask" and not hide_when_occluded:
		hide = true

	if hide:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## True when [method resolve] must run in the physics frame, because occlusion
## queries the physics space.
func wants_physics_frame() -> bool:
	return mode == Mode.NODE_FOLLOW and hide_when_occluded


## Resolves this frame's placement. [param box] is the box's current size,
## including anything drawn past its edges; [param fallback_target] is used
## when follow_target is empty.
func resolve(renderer: Node, box: Vector2, fallback_target: Node = null) -> TalkAnchorResult:
	if renderer == null or not renderer.is_inside_tree():
		return TalkAnchorResult.hidden()
	var viewport := renderer.get_viewport()
	if viewport == null:
		return TalkAnchorResult.hidden()
	var view := viewport.get_visible_rect().size
	match mode:
		Mode.SCREEN:
			return _resolve_screen(view, box)
		Mode.NODE_FOLLOW:
			return _resolve_follow(renderer, viewport, view, box, fallback_target)
	return TalkAnchorResult.hidden()


#region Screen

func _resolve_screen(view: Vector2, box: Vector2) -> TalkAnchorResult:
	var result := TalkAnchorResult.new()
	result.size = forced_size(view)
	# A forced size is a floor: content that needs more room still gets it.
	var effective := box.max(result.size)
	if screen_spot == Spot.ABSOLUTE:
		result.position = screen_position
		return result
	# A box taller or wider than the screen keeps its start in view, where the
	# name and the line begin.
	result.position = Vector2(
		_axis(_horizontal_weight(), view.x, effective.x, screen_margin.x),
		_axis(_vertical_weight(), view.y, effective.y, screen_margin.y),
	).max(screen_margin.min(view * 0.5))
	return result


## The size this placement gives the box in a [param view]-sized viewport.
## Zero on an axis keeps the box's natural size.
func forced_size(view: Vector2) -> Vector2:
	var size := box_size
	if mode == Mode.SCREEN and stretch_horizontal:
		size.x = maxf(0.0, view.x - screen_margin.x * 2.0)
	return size


## True when the box fills the viewport's width, so anything drawn past its
## edges comes out of that width.
func stretches(view: Vector2) -> bool:
	return mode == Mode.SCREEN and stretch_horizontal and view.x > 0.0


## The most room a box can take on screen in a [param view]-sized viewport,
## margins excluded. Placement keeps the box inside it.
func room(view: Vector2) -> Vector2:
	if mode == Mode.SCREEN:
		if screen_spot == Spot.ABSOLUTE:
			return (view - screen_position).max(Vector2.ZERO)
		return (view - screen_margin * 2.0).max(Vector2.ZERO)
	if when_offscreen == Offscreen.FREE:
		return view
	return (view - Vector2.ONE * viewport_margin * 2.0).max(Vector2.ZERO)


# Weight 0 = near edge, 0.5 = centred, 1 = far edge.
func _axis(weight: float, available: float, extent: float, margin: float) -> float:
	if is_equal_approx(weight, 0.5):
		return (available - extent) * 0.5
	if weight <= 0.0:
		return margin
	return available - extent - margin


func _horizontal_weight() -> float:
	match screen_spot:
		Spot.TOP_LEFT, Spot.LEFT, Spot.BOTTOM_LEFT:
			return 0.0
		Spot.TOP_RIGHT, Spot.RIGHT, Spot.BOTTOM_RIGHT:
			return 1.0
	return 0.5


func _vertical_weight() -> float:
	match screen_spot:
		Spot.TOP_LEFT, Spot.TOP, Spot.TOP_RIGHT:
			return 0.0
		Spot.BOTTOM_LEFT, Spot.BOTTOM, Spot.BOTTOM_RIGHT:
			return 1.0
	return 0.5

#endregion



#region Node follow

func _resolve_follow(
	renderer: Node,
	viewport: Viewport,
	view: Vector2,
	box: Vector2,
	fallback_target: Node,
) -> TalkAnchorResult:
	var target := _resolve_target(renderer, fallback_target)
	if target == null:
		return TalkAnchorResult.hidden()

	var point := Vector2.ZERO
	var scale := 1.0

	if target is Node3D:
		var node_3d := target as Node3D
		var camera := viewport.get_camera_3d()
		if camera == null:
			return TalkAnchorResult.hidden()
		var world := node_3d.global_position + follow_offset_3d
		# Unprojection mirrors points behind the camera onto the screen.
		if camera.is_position_behind(world):
			return TalkAnchorResult.hidden()
		var distance := camera.global_position.distance_to(world)
		if max_distance > 0.0 and distance > max_distance:
			return TalkAnchorResult.hidden()
		if hide_when_occluded and _is_occluded(node_3d, camera, world):
			return TalkAnchorResult.hidden()
		if scale_with_distance:
			scale = clampf(reference_distance / maxf(distance, 0.001), min_scale, max_scale)
		point = camera.unproject_position(world)
	elif target is Node2D:
		point = (target as Node2D).get_global_transform_with_canvas().origin
	elif target is Control:
		point = (target as Control).get_global_rect().get_center()
	else:
		return TalkAnchorResult.hidden()

	return _place(point, view, box, scale)


# Places the box so its pivot lands on point.
func _place(point: Vector2, view: Vector2, box: Vector2, scale: float) -> TalkAnchorResult:
	var result := TalkAnchorResult.new()
	result.scale = scale
	result.focus = point
	result.has_focus = true
	result.size = box_size

	# A forced size is a floor, as on screen; place and clamp what lands there.
	var extent := box.max(box_size) * scale
	var desired := point + follow_offset - extent * pivot

	if when_offscreen == Offscreen.HIDE and not Rect2(Vector2.ZERO, view).has_point(point):
		return TalkAnchorResult.hidden()
	if when_offscreen != Offscreen.FREE:
		desired = _clamped(desired, extent, view)
		# Pushed back over the speaker by the screen edge: sit on the other
		# side of them instead, as a tooltip does, when that side has room.
		if pivot.y != 0.5 and desired.y < point.y and desired.y + extent.y > point.y:
			var mirrored := point + Vector2(follow_offset.x, -follow_offset.y) \
				- extent * Vector2(pivot.x, 1.0 - pivot.y)
			var flipped := _clamped(mirrored, extent, view)
			if flipped.y >= point.y or flipped.y + extent.y <= point.y:
				desired = flipped

	result.position = desired
	return result


func _clamped(at: Vector2, extent: Vector2, view: Vector2) -> Vector2:
	return Vector2(
		clampf(at.x, viewport_margin, maxf(viewport_margin, view.x - extent.x - viewport_margin)),
		clampf(at.y, viewport_margin, maxf(viewport_margin, view.y - extent.y - viewport_margin)))


func _resolve_target(renderer: Node, fallback_target: Node) -> Node:
	if not follow_target.is_empty():
		# Relative to the NPCTalkKit node; the box lives under the viewport root.
		var owner_node := _anchor_owner(renderer)
		if owner_node != null:
			var found := owner_node.get_node_or_null(follow_target)
			if found != null:
				return found
	return fallback_target if is_instance_valid(fallback_target) else null


func _anchor_owner(renderer: Node) -> Node:
	var context: Variant = renderer.get("context")
	if context != null and context.component != null:
		return context.component
	return null


func _is_occluded(target: Node3D, camera: Camera3D, world: Vector3) -> bool:
	var world_3d := target.get_world_3d()
	if world_3d == null:
		return false
	var space := world_3d.direct_space_state
	if space == null:
		return false
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position, world, occlusion_mask, exclude)
	return not space.intersect_ray(query).is_empty()

#endregion
