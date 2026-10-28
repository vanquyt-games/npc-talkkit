@tool
## The Play / Next transport for a conversation: which line is current, and
## whether playback is moving through them. It draws nothing; the Live preview
## renders the line it points at.
class_name TalkKitPreviewTransport
extends RefCounted

## How long a finished line is held before the next one during playback.
const HOLD_SECONDS := 1.1

## The current line or the playing state changed.
signal changed

var component: NPCTalkKit
var conversation: TalkConversation
var index := 0
var playing := false

var _generation := 0


#region Cursor

func set_source(new_component: NPCTalkKit, new_conversation: TalkConversation) -> void:
	var same := new_component == component and new_conversation == conversation
	component = new_component
	conversation = new_conversation
	if not same:
		index = 0
		if playing:
			stop()


func line_count() -> int:
	return conversation.lines.size() if conversation != null else 0


func current_line() -> TalkLine:
	if index < 0 or index >= line_count():
		return null
	return conversation.lines[index]


func has_next() -> bool:
	return index + 1 < line_count()


## Moves the cursor to [param wanted], wrapping past either end.
func go_to(wanted: int) -> void:
	var total := line_count()
	if total == 0:
		index = 0
		return
	index = posmod(wanted, total)


func describe() -> String:
	var total := line_count()
	if total == 0:
		return "Nothing to preview"
	return "Line %d of %d" % [index + 1, total]

#endregion


#region Transport

## Steps one line, wrapping at the end. Stops playback.
func next() -> void:
	playing = false
	_generation += 1
	go_to(index + 1)
	changed.emit()


## Starts playback, or stops it if it is running.
func toggle_play() -> void:
	if playing:
		stop()
	else:
		play()


## Plays from the current line to the last one, then stops on it. Does not loop.
func play() -> void:
	if current_line() == null:
		return
	playing = true
	_generation += 1
	changed.emit()
	_queue_next_line()


## Stops playback without moving the cursor.
func stop() -> void:
	playing = false
	_generation += 1
	changed.emit()


## Waits for the line to play out, then advances. A Stop or a manual step
## bumps the generation, which cancels a wait already in flight.
func _queue_next_line() -> void:
	var generation := _generation
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.create_timer(_estimated_duration() + HOLD_SECONDS).timeout
	if generation != _generation or not playing:
		return
	if not has_next():
		playing = false
		changed.emit()
		return
	go_to(index + 1)
	changed.emit()
	_queue_next_line()


func _estimated_duration() -> float:
	var line := current_line()
	if line == null or component == null:
		return 0.0
	var speed := component.resolve_typing_speed(line, conversation)
	if speed <= 0.0:
		return 0.0
	return line.text.length() / speed

#endregion
