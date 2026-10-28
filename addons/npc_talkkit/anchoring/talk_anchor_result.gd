## The placement a [TalkAnchor] resolved for one frame, returned by
## [method TalkAnchor.resolve].
class_name TalkAnchorResult
extends RefCounted

## False hides the box this frame.
var visible := true

## Top-left of the box in screen space.
var position := Vector2.ZERO

## Uniform scale. 1.0 unless distance scaling is on.
var scale := 1.0

## Forced box size; zero on an axis keeps the natural size.
var size := Vector2.ZERO

## The tracked point in screen space, used to aim a tail. Only meaningful
## when [member has_focus] is true.
var focus := Vector2.ZERO

## True when the placement tracks a point, so a tail has something to aim at.
var has_focus := false


func _init(is_visible := true, at := Vector2.ZERO, with_scale := 1.0) -> void:
	visible = is_visible
	position = at
	scale = with_scale


static func hidden() -> TalkAnchorResult:
	return TalkAnchorResult.new(false)
