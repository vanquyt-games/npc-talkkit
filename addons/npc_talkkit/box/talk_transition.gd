@tool
## How a dialogue box appears and leaves.
##
## A transition tweens [code]transition_alpha[/code],
## [code]transition_offset[/code] and [code]transition_scale[/code] on the
## renderer, which combines them with the anchored placement each frame. It
## never writes the box control directly, because the anchor overwrites position
## and scale every frame.
##
## For a custom effect, subclass and override [method play_in] and
## [method play_out].
class_name TalkTransition
extends Resource

enum Kind { NONE, FADE, SLIDE, SCALE_POP }

@export var kind: Kind = Kind.FADE
@export_range(0.0, 2.0, 0.01) var duration := 0.18
@export var curve: Tween.TransitionType = Tween.TRANS_CUBIC
@export var easing: Tween.EaseType = Tween.EASE_OUT
## Where a SLIDE starts from, relative to the resting place.
@export var slide_offset := Vector2(0.0, 24.0)
@export_range(0.05, 2.0, 0.01) var scale_from := 0.92


static func builtin(of_kind: Kind, seconds := 0.18) -> TalkTransition:
	var transition := TalkTransition.new()
	transition.kind = of_kind
	transition.duration = seconds
	return transition


## True when this transition has nothing to animate.
func is_instant() -> bool:
	return kind == Kind.NONE or duration <= 0.0


## Animates the box into view. Await it.
func play_in(box: Node) -> void:
	await _run(box, true)


## Animates the box out of view. Await it.
func play_out(box: Node) -> void:
	await _run(box, false)


## The fully shown state: alpha, offset and scale.
func rest_state() -> Dictionary:
	return {"alpha": 1.0, "offset": Vector2.ZERO, "scale": 1.0}


## The fully hidden state for this [member kind].
func away_state() -> Dictionary:
	match kind:
		Kind.FADE:
			return {"alpha": 0.0, "offset": Vector2.ZERO, "scale": 1.0}
		Kind.SLIDE:
			return {"alpha": 0.0, "offset": slide_offset, "scale": 1.0}
		Kind.SCALE_POP:
			return {"alpha": 0.0, "offset": Vector2.ZERO, "scale": scale_from}
	return rest_state()


func _run(box: Node, entering: bool) -> void:
	if box == null or not box.is_inside_tree():
		return
	var from := away_state() if entering else rest_state()
	var to := rest_state() if entering else away_state()
	if is_instant():
		_write(box, to)
		return
	_write(box, from)
	var tween := box.create_tween()
	tween.set_parallel(true)
	tween.set_trans(curve).set_ease(easing)
	tween.tween_property(box, "transition_alpha", to["alpha"], duration)
	tween.tween_property(box, "transition_offset", to["offset"], duration)
	tween.tween_property(box, "transition_scale", to["scale"], duration)
	if box.has_method("_track_transition"):
		box.call("_track_transition", tween)
	# Wait on a timer, not the tween: a killed tween never emits `finished`,
	# which would leave this coroutine and its callers suspended.
	await box.get_tree().create_timer(duration).timeout


func _write(box: Node, values: Dictionary) -> void:
	box.set("transition_alpha", values["alpha"])
	box.set("transition_offset", values["offset"])
	box.set("transition_scale", values["scale"])
