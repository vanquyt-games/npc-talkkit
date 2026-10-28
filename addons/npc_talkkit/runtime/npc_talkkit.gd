@tool
@icon("res://addons/npc_talkkit/icons/npc_talkkit.svg")
class_name NPCTalkKit
extends Node

## Plays named NPC conversations the way AnimationPlayer plays named animations.
##
## Content lives on this node in [member conversations]. A shared [TalkKitDatabase]
## can be assigned as a library, but is not required.
##
## The game owns the logic; this node owns playback and the dialogue box.

signal conversation_started(conversation_id: StringName)
signal line_started(line: TalkLine)
signal line_finished(line: TalkLine)

## Emitted when a non-blocking line event fires. Playback continues.
signal event_triggered(event_id: StringName, payload: Variant)

## Playback is paused. The host must call [method resume], [method stop], or
## [method play] on another conversation.
signal event_blocked(event_id: StringName, payload: Variant)

signal conversation_finished(conversation_id: StringName)
signal conversation_cancelled(conversation_id: StringName)
signal speech_started(line: TalkLine)
signal speech_progress(normalized_progress: float)
signal speech_finished(line: TalkLine)
signal request_player_lock(locked: bool)
signal request_face_target(target: Node)
signal request_camera_focus(target: Node)

enum State { IDLE, OPENING, DISPLAYING, BLOCKED, FINISHING, CANCELLING }

const BOX_SCENE_PATH := "res://addons/npc_talkkit/box/talk_box.tscn"
const DEFAULT_TEMPLATE_PATH := "res://addons/npc_talkkit/templates/classic_panel.tres"

## Conversations this NPC can play. Empty is valid: [method say] needs nothing
## authored.
@export var conversations: Array[TalkConversation] = []

## The speakers this node can use. Conversations and lines pick from this
## collection; it is not a default.
@export var speakers: Array[TalkSpeaker] = []

## The dialogue boxes this node can use. Conversations and lines pick from this
## collection.
@export var dialogue_boxes: Array[TalkBoxTemplate] = []

## Defaults for [method say] when its content and options do not name a
## speaker, box or placement. Saved conversations never use them.
@export_group("Quick Say")
@export var quick_say_speaker: TalkSpeaker
@export var quick_say_dialogue_box: TalkBoxTemplate
@export var quick_say_placement: TalkAnchor

@export_group("Advanced Runtime")
## Optional shared library, searched after conversations.
@export var library: TalkKitDatabase
## Merged under the params passed to [method play].
@export var default_params: Dictionary = {}
@export var conversation_target: Node
@export var box_parent_path: NodePath
@export var request_lock_on_start := true
@export var request_face_on_start := false
@export var request_camera_on_start := false


var state := State.IDLE
## A box still playing its close transition, reused if a conversation starts
## again before it finishes.
var _closing: Node
var _closing_id: StringName = &""
var _conversation: TalkConversation
var _line_index := -1
var _params: Dictionary = {}
var _box: Node
var _box_id: StringName
var _voice_player: AudioStreamPlayer


## Removed properties and their replacements. GDScript silently accepts an
## assignment to a property that does not exist, so [method _set] reports these
## as errors instead.
const _MOVED := {
	"speaker": "speakers (a collection), or quick_say_speaker for say()",
	"dialogue_box": "dialogue_boxes (a collection), or quick_say_dialogue_box for say()",
	"anchor": "the conversation's default_placement, or quick_say_placement for say()",
	"profile": "speakers",
	"speaker_name": "a TalkSpeaker in speakers",
	"portrait": "TalkSpeaker.visual",
	"voice_blip": "TalkSpeaker.voice_blip",
	"voice_enabled": "TalkSpeaker.voice_enabled",
	"animation_player_path": "nothing — your game plays its own animations",
	"animated_sprite_path": "nothing — your game plays its own animations",
}


func _set(property: StringName, _value: Variant) -> bool:
	if _MOVED.has(property):
		push_error("NPCTalkKit.%s was removed in 2.0. Use %s." % [property, _MOVED[property]])
		# Returning true stops Godot from storing a stray dynamic property.
		return true
	return false


func _ready() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoiceClipPlayer"
	add_child(_voice_player)


#region Playback

## Plays a conversation by name. [param params] fills {{placeholders}} in the
## text. Returns false when the name is unknown, the content fails validation,
## or a conversation is already running.
##
## [codeblock]
## idle                 starts
## opening / speaking   refused
## blocked              allowed: answers a blocking event with a branch,
##                      reusing the open box
## [/codeblock]
func play(conversation_id: StringName, params: Dictionary = {}) -> bool:
	var candidate := find_conversation(conversation_id)
	if candidate == null:
		push_warning("NPCTalkKit conversation '%s' was not found." % conversation_id)
		return false
	if state == State.BLOCKED:
		# Validate before abandoning, or a refusal would leave the player locked.
		if not _accepts(candidate):
			return false
		_abandon()
	elif state != State.IDLE:
		push_warning("NPCTalkKit is already running a conversation.")
		return false
	return _begin(candidate, params)


## Drops the current conversation without emitting cancellation or releasing
## the player lock, and keeps the box, so the next conversation takes them over.
func _abandon() -> void:
	_conversation = null
	_line_index = -1
	_params = {}
	state = State.IDLE


## Returns true if [param conversation] passes validation; warns otherwise.
func _accepts(conversation: TalkConversation) -> bool:
	var report := TalkValidator.validate_conversation(conversation, known_speakers())
	if report.is_valid():
		return true
	push_warning("NPCTalkKit refused invalid conversation '%s': %s" % [
		conversation.conversation_id, JSON.stringify(report.to_dictionary(false))
	])
	return false


func _begin(conversation: TalkConversation, params: Dictionary) -> bool:
	if state != State.IDLE:
		push_warning("NPCTalkKit is already running a conversation.")
		return false
	if not _accepts(conversation):
		return false

	_conversation = conversation
	_line_index = -1
	_params = default_params.duplicate()
	_params.merge(params, true)
	state = State.OPENING
	conversation_started.emit(conversation.conversation_id)
	if request_lock_on_start:
		request_player_lock.emit(true)
	var target := _target()
	if request_face_on_start:
		request_face_target.emit(target)
	if request_camera_on_start:
		request_camera_focus.emit(target)
	advance()
	return true


## Speaks content without any authored conversation.
##
## [param content] is a String, a [TalkLine], or an Array mixing the two.
## [param options] may set [code]speaker[/code], [code]dialogue_box[/code] and
## [code]placement[/code]:
##
## [codeblock]
## $NPCTalkKit.say("Hello there.")
## $NPCTalkKit.say(["Line one.", "Line two."], {"name": "Alex"})
##
## $NPCTalkKit.say("[color=#ff6b6b]Stop![/color]",
##     {}, {"speaker": &"ren", "dialogue_box": &"warning"})
##
## $NPCTalkKit.say("Three days later…", {}, {"speaker": null})   # narrator
## [/codeblock]
##
## An option may be a resource or the id of one this node carries. A key set to
## null means none ([code]{"speaker": null}[/code] is a narrator); a missing key
## falls back to the Quick Say defaults. Options select existing resources; they
## do not create or edit them.
##
## The content plays as an unsaved conversation through the same pipeline as
## [method play], with the same blocking rules.
func say(content: Variant, params: Dictionary = {}, options: Dictionary = {}) -> bool:
	var conversation := _quick_say_conversation(content, options)
	if conversation == null:
		push_warning("NPCTalkKit.say() needs a String, a TalkLine, or an Array of them.")
		return false
	if state == State.BLOCKED:
		# Validate before abandoning, as in play().
		if not _accepts(conversation):
			return false
		_abandon()
	return _begin(conversation, params)


## Builds the unsaved conversation [method say] plays, with the Quick Say
## defaults and [param options] as its defaults.
func _quick_say_conversation(content: Variant, options: Dictionary) -> TalkConversation:
	var conversation := transient_conversation(content)
	if conversation == null:
		return null
	conversation.default_speaker = quick_say_speaker
	conversation.default_dialogue_box = quick_say_dialogue_box
	conversation.default_placement = quick_say_placement
	if options.has("speaker"):
		conversation.default_speaker = _as_speaker(options["speaker"])
	if options.has("dialogue_box"):
		conversation.default_dialogue_box = _as_dialogue_box(options["dialogue_box"])
	if options.has("placement"):
		conversation.default_placement = options["placement"] as TalkAnchor
	return conversation


## Resolves an option value to a speaker: a resource, or the id of one this
## node carries.
func _as_speaker(value: Variant) -> TalkSpeaker:
	if value is TalkSpeaker:
		return value
	if value is StringName or value is String:
		var found := find_speaker(StringName(value))
		if found == null:
			push_warning("NPCTalkKit has no speaker '%s'." % value)
		return found
	return null


func _as_dialogue_box(value: Variant) -> TalkBoxTemplate:
	if value is TalkBoxTemplate:
		return value
	if value is StringName or value is String:
		var found := find_dialogue_box(StringName(value))
		if found == null:
			push_warning("NPCTalkKit has no dialogue box '%s'." % value)
		return found
	return null


## Builds an unsaved conversation from [method say] content, or returns null if
## the content is not a String, a [TalkLine], or an Array of them.
static func transient_conversation(content: Variant) -> TalkConversation:
	var conversation := TalkConversation.new()
	conversation.conversation_id = &"__say"
	for item in (content if content is Array else [content]):
		if item is TalkLine:
			conversation.lines.append(item)
		elif item is String or item is StringName:
			var line := TalkLine.new()
			line.text = str(item)
			conversation.lines.append(line)
		else:
			return null
	return null if conversation.lines.is_empty() else conversation


## Completes the current line if it is still typing, otherwise moves to the
## next line. Does nothing while blocked; respond to [signal event_blocked] first.
func advance() -> void:
	if state == State.IDLE or state == State.BLOCKED or _conversation == null:
		return
	if _box != null and _box.has_method("is_typing") and _box.call("is_typing"):
		_box.call("finish_line")
		return
	if _line_index >= 0 and _line_index < _conversation.lines.size():
		if _finish_current_line():
			return
	_step()


## Continues playback after a blocking event.
func resume() -> void:
	if state != State.BLOCKED:
		return
	state = State.DISPLAYING
	_step()


func stop() -> void:
	if state == State.IDLE:
		return
	state = State.CANCELLING
	var cancelled_id := _conversation.conversation_id if _conversation != null else StringName()
	_cleanup()
	conversation_cancelled.emit(cancelled_id)


func is_running() -> bool:
	return state != State.IDLE


func is_blocked() -> bool:
	return state == State.BLOCKED

#endregion


#region Lookup

## Finds a conversation on this node first, then in [member library]. A node
## entry overrides a library conversation with the same id.
func find_conversation(conversation_id: StringName) -> TalkConversation:
	for conversation in conversations:
		if conversation != null and conversation.conversation_id == conversation_id:
			return conversation
	if library != null:
		return library.get_conversation(conversation_id)
	return null


## Ids of every conversation this node can play, node entries first.
func list_conversations() -> Array[StringName]:
	var names: Array[StringName] = []
	for conversation in conversations:
		if conversation != null and not names.has(conversation.conversation_id):
			names.append(conversation.conversation_id)
	if library != null:
		for id in library.list_conversations():
			if not names.has(id):
				names.append(id)
	return names


#endregion


#region Line flow

func _step() -> void:
	_line_index += 1
	if _line_index >= _conversation.lines.size():
		_finish_conversation()
		return
	_show_current_line()


## Deferred variant of [method _show_current_line]; does nothing if playback
## stopped in the meantime.
func _show_current_line_when_ready() -> void:
	if _conversation == null or state == State.IDLE:
		return
	_show_current_line()


func _show_current_line() -> void:
	var parent := _box_parent()
	# add_child() fails while the parent is still being built (play() from
	# _ready()), so wait a frame.
	if not parent.is_node_ready():
		call_deferred("_show_current_line_when_ready")
		return
	var source := _conversation.lines[_line_index]
	if not _ensure_box(source):
		stop()
		return

	# Render into a copy: the line may be a shared resource.
	var line := _render(source)

	state = State.DISPLAYING
	if line.voice_clip != null and _voice_player != null:
		_voice_player.stream = line.voice_clip
		_voice_player.play()
	line_started.emit(line)
	_box.call("show_line", line)


## Returns true when playback has paused on a blocking event.
func _finish_current_line() -> bool:
	var source := _conversation.lines[_line_index]
	if _box != null and _box.has_method("finish_line"):
		_box.call("finish_line")
	if _voice_player != null and _voice_player.playing:
		_voice_player.stop()
	line_finished.emit(source)
	if source.event_id.is_empty():
		return false
	if source.event_blocking:
		state = State.BLOCKED
		event_blocked.emit(source.event_id, source.event_payload)
		return true
	event_triggered.emit(source.event_id, source.event_payload)
	return false


func _finish_conversation() -> void:
	state = State.FINISHING
	var finished_id := _conversation.conversation_id
	var event_id := _conversation.event_id
	var payload: Variant = _conversation.event_payload
	_cleanup()
	if not event_id.is_empty():
		event_triggered.emit(event_id, payload)
	conversation_finished.emit(finished_id)


func _cleanup() -> void:
	if _voice_player != null:
		_voice_player.stop()
	if _box != null:
		if _box.has_method("close"):
			# close() frees the box after its transition. Keep a reference so a
			# conversation starting during the fade can reopen it.
			_closing = _box
			_closing_id = _box_id
			_box.call("close")
		else:
			_box.queue_free()
	_box = null
	_box_id = &""
	if request_lock_on_start:
		request_player_lock.emit(false)
	_conversation = null
	_line_index = -1
	_params = {}
	state = State.IDLE

#endregion


#region Resolution

# Every value resolves through two levels: line override, then conversation
# default. say() content carries the Quick Say defaults as its
# conversation defaults.

## Returns the speaker of [param line], or null for no speaker. A line with
## [constant TalkLine.SpeakerMode.NONE], or a conversation without a default
## speaker, still plays; the box shows no name or face.
func resolve_speaker(line: TalkLine = null, conversation: TalkConversation = null) -> TalkSpeaker:
	var source := conversation if conversation != null else _conversation
	if line != null:
		match line.speaker_mode:
			TalkLine.SpeakerMode.NONE:
				return null
			TalkLine.SpeakerMode.SPEAKER:
				if line.speaker != null:
					return line.speaker
				return find_speaker(line.speaker_id)
	return source.default_speaker if source != null else null


## Returns the dialogue box for [param line]. Falls back to
## [method default_template] when neither the line nor the conversation sets
## one; the validator reports that case.
func resolve_dialogue_box(line: TalkLine = null, conversation: TalkConversation = null) -> TalkBoxTemplate:
	var source := conversation if conversation != null else _conversation
	if line != null and line.dialogue_box != null:
		return line.dialogue_box
	if source != null and source.default_dialogue_box != null:
		return source.default_dialogue_box
	return default_template()


## Returns the placement for [param line], or null to use the renderer's own
## placement.
func resolve_placement(line: TalkLine = null, conversation: TalkConversation = null) -> TalkAnchor:
	var source := conversation if conversation != null else _conversation
	if line != null and line.placement != null:
		return line.placement
	return source.default_placement if source != null else null


## Returns characters per second for [param line]: the line's
## [member TalkLine.characters_per_second] if above 0, otherwise the box's
## [member TalkBoxTemplate.typewriter_speed]. 0 shows the line at once.
func resolve_typing_speed(line: TalkLine = null, conversation: TalkConversation = null) -> float:
	if line != null and line.characters_per_second > 0.0:
		return line.characters_per_second
	var template := resolve_dialogue_box(line, conversation)
	return template.typewriter_speed if template != null else 40.0


## Returns the visual for [param line]'s [member TalkLine.visual_variant]. An
## unknown variant falls back to the speaker's default visual.
func resolve_dialogue_visual(for_speaker: TalkSpeaker, line: TalkLine = null) -> TalkDialogueVisual:
	if for_speaker == null:
		return null
	var variant := line.visual_variant if line != null else StringName()
	var visual := for_speaker.resolve_visual(variant)
	return null if visual == null or visual.is_empty() else visual


## Returns the name shown in the box: the line's
## [member TalkLine.display_name_override] if set, otherwise the speaker's name.
func resolve_display_name(for_speaker: TalkSpeaker, line: TalkLine = null) -> String:
	if line != null and not line.display_name_override.is_empty():
		return line.display_name_override
	return for_speaker.display_name if for_speaker != null else ""


## Returns the speaker whose voice blips play while [param line] types, or
## null for silence.
func resolve_voice(line: TalkLine = null, conversation: TalkConversation = null) -> TalkSpeaker:
	var for_speaker := resolve_speaker(line, conversation)
	if for_speaker == null or not for_speaker.voice_enabled or for_speaker.voice_blip == null:
		return null
	return for_speaker


## Returns the node a following box tracks. Used only as a position.
func resolve_follow_target(_line: TalkLine = null) -> Node:
	return _target()

#endregion


#region Collections

## Returns the speaker with [param speaker_id] from [member speakers] or the
## library, or null.
func find_speaker(speaker_id: StringName) -> TalkSpeaker:
	if speaker_id.is_empty():
		return null
	for entry in speakers:
		if entry != null and entry.speaker_id == speaker_id:
			return entry
	if library != null:
		return library.get_speaker(speaker_id)
	return null


## Returns the box in [member dialogue_boxes] whose resource_name or file name
## (without extension) equals [param box_id], or null.
func find_dialogue_box(box_id: StringName) -> TalkBoxTemplate:
	if box_id.is_empty():
		return null
	var wanted := String(box_id)
	for box in dialogue_boxes:
		if box == null:
			continue
		if box.resource_name == wanted:
			return box
		if box.resource_path.get_file().get_basename() == wanted:
			return box
	return null


## Returns every speaker this node can show: [member speakers], speakers its
## conversations reference directly, and the library's speakers.
func known_speakers() -> Array[TalkSpeaker]:
	var found: Array[TalkSpeaker] = []
	for entry in speakers:
		if entry != null and not found.has(entry):
			found.append(entry)
	for conversation in conversations:
		if conversation == null:
			continue
		if conversation.default_speaker != null and not found.has(conversation.default_speaker):
			found.append(conversation.default_speaker)
		for line in conversation.lines:
			if line != null and line.speaker != null and not found.has(line.speaker):
				found.append(line.speaker)
	if library != null:
		for entry in library.speakers:
			if entry != null and not found.has(entry):
				found.append(entry)
	return found

#endregion


#region Text parameters

## Returns a copy of [param source] translated for the current locale, then
## with {{placeholders}} substituted. The line as written is the translation
## key, so a key that carries a placeholder still matches. line_id is preserved.
func _render(source: TalkLine) -> TalkLine:
	var text := tr(source.text)
	if text.contains("{{"):
		text = substitute(text, _params)
	if text == source.text:
		return source
	var line := source.duplicate_line()
	line.text = text
	return line


## Replaces {{key}} placeholders in [param text] with values from [param params]
## in a single, non-recursive pass. An unknown key is left as written and
## reported with a warning.
static func substitute(text: String, params: Dictionary) -> String:
	var regex := RegEx.new()
	regex.compile("\\{\\{\\s*([A-Za-z0-9_.-]+)\\s*\\}\\}")
	var result := ""
	var cursor := 0
	for found in regex.search_all(text):
		var key := found.get_string(1)
		result += text.substr(cursor, found.get_start() - cursor)
		if params.has(key):
			result += str(params[key])
		else:
			push_warning("NPCTalkKit has no value for '{{%s}}'." % key)
			result += found.get_string()
		cursor = found.get_end()
	return result + text.substr(cursor)

#endregion


#region Presentation

func _ensure_box(line: TalkLine) -> bool:
	var id := _renderer_id(resolve_dialogue_box(line))
	if _box != null and _box_id == id:
		_box.call("setup", build_context(line))
		return true
	if _box == null and is_instance_valid(_closing) and _closing_id == id:
		_box = _closing
		_box_id = _closing_id
		_closing = null
		if _box.has_method("reopen"):
			_box.call("reopen")
		_box.call("setup", build_context(line))
		return true
	if _box != null:
		_box.call("close") if _box.has_method("close") else _box.queue_free()
		_box = null
	var scene := _renderer_scene(resolve_dialogue_box(line))
	if scene == null:
		push_warning("NPCTalkKit could not load the dialogue box renderer.")
		return false
	_box = scene.instantiate()
	for method in ["setup", "show_line", "finish_line", "close"]:
		if not _box.has_method(method):
			push_warning("NPCTalkKit renderer is missing method '%s'." % method)
			_box.queue_free()
			_box = null
			return false
	_box_parent().add_child(_box)
	_box_id = id
	_box.call("setup", build_context(line))
	if _box.has_signal("advance_requested"):
		_box.connect("advance_requested", advance)
	if _box.has_signal("speech_started"):
		_box.connect("speech_started", func(line: TalkLine) -> void: speech_started.emit(line))
	if _box.has_signal("speech_progress"):
		_box.connect("speech_progress", func(_line: TalkLine, progress: float) -> void: speech_progress.emit(progress))
	if _box.has_signal("speech_finished"):
		_box.connect("speech_finished", func(line: TalkLine) -> void: speech_finished.emit(line))
	return true


## Returns the resolved state a renderer needs to draw [param line]. Usable
## without a running conversation.
func build_context(line: TalkLine = null, conversation: TalkConversation = null) -> TalkContext:
	var source := conversation if conversation != null else _conversation
	var active := resolve_speaker(line, source)
	var drawn: Array[TalkRenderParticipant] = []
	var speaking: TalkRenderParticipant
	if active != null or line != null:
		speaking = TalkRenderParticipant.new(
			active,
			resolve_display_name(active, line),
			resolve_dialogue_visual(active, line),
			true)
		drawn.append(speaking)
	return TalkContext.new(
		self, resolve_follow_target(line), source,
		resolve_placement(line, source), resolve_dialogue_box(line, source),
		resolve_typing_speed(line, source), speaking, drawn)


## Returns the fallback box (the Classic Panel), or a default
## [TalkBoxTemplate] if that file is missing.
static func default_template() -> TalkBoxTemplate:
	var shipped := load(DEFAULT_TEMPLATE_PATH) as TalkBoxTemplate
	return shipped if shipped != null else TalkBoxTemplate.new()


## Returns the node the box is added to: [member box_parent_path] if set,
## otherwise the viewport root.
func _box_parent() -> Node:
	if not box_parent_path.is_empty():
		var named := get_node_or_null(box_parent_path)
		if named != null:
			return named
	return get_tree().root if is_inside_tree() else self


## Returns the template's renderer scene, or the built-in box.
func _renderer_scene(template: TalkBoxTemplate) -> PackedScene:
	if template != null and template.renderer != null:
		return template.renderer
	return load(BOX_SCENE_PATH) as PackedScene


## Identifies a renderer so the open box is reused between lines that share it.
func _renderer_id(template: TalkBoxTemplate) -> StringName:
	if template != null and template.renderer != null:
		return StringName(template.renderer.resource_path)
	return &"__builtin"


#endregion


#region Host hooks

## Returns [member conversation_target], or the parent node if unset. Passed to
## the request_* signals and tracked by following boxes.
func _target() -> Node:
	return conversation_target if is_instance_valid(conversation_target) else get_parent()

#endregion


func _exit_tree() -> void:
	if state != State.IDLE:
		_cleanup()
