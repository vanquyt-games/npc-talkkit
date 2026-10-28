extends Node3D

## Minimal 3D showcase for NPC TalkKit, built from Godot primitives.
## Walk up to a villager and press Space or Enter.

const SPEED := 4.5
const GRAVITY := 22.0

@onready var _player: CharacterBody3D = %Player
@onready var _hint: Label = %Hint

var _locked := false


func _ready() -> void:
	for kit in find_children("*", "NPCTalkKit", true, false):
		kit.request_player_lock.connect(_on_player_lock)
	for area in find_children("*", "TalkInteractionArea3D", true, false):
		area.availability_changed.connect(_on_availability)


func _physics_process(delta: float) -> void:
	if not _player.is_on_floor():
		_player.velocity.y -= GRAVITY * delta
	else:
		_player.velocity.y = 0.0

	var input := Input.get_vector(
		&"ui_left", &"ui_right", &"ui_up", &"ui_down") if not _locked else Vector2.ZERO
	_player.velocity.x = input.x * SPEED
	_player.velocity.z = input.y * SPEED
	_player.move_and_slide()


func _on_player_lock(locked: bool) -> void:
	_locked = locked
	if locked:
		_player.velocity.x = 0.0
		_player.velocity.z = 0.0


func _on_availability(available: bool) -> void:
	_hint.visible = available and not _locked
