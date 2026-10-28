@tool
extends VBoxContainer

## Contextual editor for one TalkLine. The conversation row stays text-first;
## this pane carries the exceptional state that only some lines need.

signal changed
signal navigate_resource(section: String, resource: Resource)

const InlinePreview := preload("res://addons/npc_talkkit/editor/talkkit_inline_preview.gd")
const PlacementEditor := preload("res://addons/npc_talkkit/editor/talkkit_placement_editor.gd")

const SPEAKER_INHERIT := 0
const SPEAKER_NONE := 1
const SPEAKER_FIRST := 2
const BOX_INHERIT := 0
const BOX_FIRST := 1

var component: NPCTalkKit
var conversation: TalkConversation
var line: TalkLine
var line_index := -1
var editor_plugin: EditorPlugin

var _title: Label
var _summary: Label
var _reset: Button
var _preview: VBoxContainer
var _inline_preview: TextureRect
var _settings: VBoxContainer
var _speaker: OptionButton
var _display_name: LineEdit
var _variant: LineEdit
var _box: OptionButton
var _placement: EditorResourcePicker
var _placement_editor: VBoxContainer
var _speed: SpinBox
var _voice: EditorResourcePicker
var _event_id: LineEdit
var _event_blocking: CheckBox
var _payload: TextEdit
var _line_id: LineEdit
var _field_rows: Dictionary = {}
var _section_rows: Dictionary = {}
var _reset_buttons: Dictionary = {}
var _manager_buttons: Dictionary = {}
var _updating := false
var _show_all := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	refresh()


func _build() -> void:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	add_child(header)

	var headings := VBoxContainer.new()
	headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(headings)
	_title = Label.new()
	_title.text = "Line details"
	_title.add_theme_font_size_override("font_size", 14)
	headings.add_child(_title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 11)
	_summary.modulate.a = 0.7
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headings.add_child(_summary)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	header.add_child(actions)
	_reset = Button.new()
	_reset.text = "Reset"
	_reset.tooltip_text = "Make this line inherit every conversation default"
	_reset.pressed.connect(_confirm_reset_overrides)
	actions.add_child(_reset)

	var show := Button.new()
	show.text = "Add override…"
	show.name = "ShowSettings"
	show.pressed.connect(func() -> void:
		_show_all = not _show_all
		refresh())
	actions.add_child(show)

	var rule := HSeparator.new()
	add_child(rule)

	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 5)
	add_child(_preview)
	var preview_heading := Label.new()
	preview_heading.text = "Live preview"
	preview_heading.add_theme_font_size_override("font_size", 10)
	preview_heading.modulate.a = 0.62
	_preview.add_child(preview_heading)
	_inline_preview = InlinePreview.new()
	_preview.add_child(_inline_preview)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_settings = VBoxContainer.new()
	_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings.add_theme_constant_override("separation", 6)
	scroll.add_child(_settings)

	_section("Identity", "identity")
	_speaker = _option("Speaker", _on_speaker, "speaker")
	_manager_button("speaker", "Edit speaker ↗", "speakers")
	_display_name = _text("Display name override", _on_display_name, "display_name_override")
	_variant = _text("Visual variant", _on_variant, "visual_variant")

	_section("Presentation", "presentation")
	_box = _option("Dialogue Box", _on_box, "dialogue_box")
	_manager_button("dialogue_box", "Edit dialogue box ↗", "boxes")
	_placement_editor = PlacementEditor.new()
	_placement_editor.editor_plugin = editor_plugin
	_placement_editor.replacement_requested.connect(_on_placement)
	_placement_editor.changed.connect(_on_placement_edited)
	_field("Placement", _placement_editor, "placement")
	_speed = SpinBox.new()
	_speed.min_value = 0.0
	_speed.max_value = 240.0
	_speed.step = 1.0
	_speed.suffix = " chars/s"
	_speed.value_changed.connect(_on_speed)
	_field("Typing speed · 0 inherits from the box", _speed, "characters_per_second")

	_section("Audio", "audio")
	_resource("Voice clip", "AudioStream", _on_voice, false, "voice_clip")

	_section("Event", "event")
	_event_id = _text("Event id", _on_event_id, "event_id")
	_event_blocking = CheckBox.new()
	_event_blocking.text = "Pause playback until the game responds"
	_event_blocking.toggled.connect(_on_event_blocking)
	_field("Blocking", _event_blocking, "event_blocking")
	_payload = TextEdit.new()
	_payload.custom_minimum_size.y = 62
	_payload.placeholder_text = "JSON payload · null, number, string, array or object"
	_payload.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_payload.focus_exited.connect(_on_payload_committed)
	_field("Event payload", _payload, "event_payload")

	_section("Advanced", "advanced")
	_line_id = _text("Stable line id", _on_line_id, "line_id")


func _section(text: String, key: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate.a = 0.72
	label.add_theme_constant_override("outline_size", 0)
	_settings.add_child(label)
	_section_rows[key] = label


func _field(label_text: String, control: Control, key := "") -> void:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 2)
	var heading := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate.a = 0.7
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	if not key.is_empty():
		var reset := Button.new()
		reset.text = "Reset"
		reset.flat = true
		reset.tooltip_text = "Reset this field to its inherited value"
		reset.add_theme_font_size_override("font_size", 10)
		reset.pressed.connect(_reset_property.bind(key))
		heading.add_child(reset)
		_reset_buttons[key] = reset
	field.add_child(heading)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(control)
	_settings.add_child(field)
	if not key.is_empty():
		_field_rows[key] = field


func _manager_button(field_key: String, text: String, section: String) -> void:
	var field := _field_rows.get(field_key) as VBoxContainer
	if field == null:
		return
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_navigate_manager.bind(section))
	field.add_child(button)
	_manager_buttons[field_key] = button


func _option(label_text: String, callback: Callable, key: String) -> OptionButton:
	var option := OptionButton.new()
	option.clip_text = true
	option.fit_to_longest_item = false
	option.item_selected.connect(callback)
	_field(label_text, option, key)
	return option


func _text(label_text: String, callback: Callable, key: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text_changed.connect(callback)
	_field(label_text, edit, key)
	return edit


func _resource(
	label_text: String,
	base_type: String,
	callback: Callable,
	is_placement: bool,
	key: String,
) -> void:
	# EditorResourcePicker exists only in the editor; elsewhere a label stands in.
	if not Engine.is_editor_hint():
		var fallback := Label.new()
		fallback.text = "Available in the Godot editor"
		fallback.modulate.a = 0.65
		_field(label_text, fallback, key)
		return
	var picker := EditorResourcePicker.new()
	picker.base_type = base_type
	picker.resource_changed.connect(callback)
	_field(label_text, picker, key)
	if is_placement:
		_placement = picker
	else:
		_voice = picker


## When true, the Live preview plays the line instead of showing it finished.
func set_preview_animated(value: bool) -> void:
	_inline_preview.set_animate(value)


## Redraws the Live preview, for an edit made outside this panel such as
## typing in the line's row.
func refresh_preview() -> void:
	_inline_preview.refresh()


func set_line(
	new_component: NPCTalkKit,
	new_conversation: TalkConversation,
	new_line: TalkLine,
	index: int,
) -> void:
	component = new_component
	conversation = new_conversation
	line = new_line
	line_index = index
	_show_all = false
	refresh()


func refresh() -> void:
	if _title == null:
		return
	_updating = true
	var has_line := line != null
	if has_line:
		_title.text = "Line %d" % (line_index + 1)
		_summary.text = describe(line, conversation)
	elif conversation != null:
		_title.text = String(conversation.conversation_id)
		_summary.text = "Select a line to preview it and edit its exceptions."
	elif component != null:
		_title.text = component.name
		_summary.text = "%d conversations · %d speakers · %d dialogue boxes" % [
			component.conversations.size(), component.speakers.size(), component.dialogue_boxes.size(),
		]
	else:
		_title.text = "Line details"
		_summary.text = "Select a line to inspect its exceptions."
	_preview.visible = has_line
	_inline_preview.set_preview(component, conversation, line)
	_refresh_field_visibility()
	var show := get_node_or_null("ShowSettings") as Button
	# The button lives in the header, so it is found recursively.
	show = find_child("ShowSettings", true, false) as Button
	if show != null:
		show.disabled = not has_line
		show.visible = has_line
		show.text = "Done" if _show_all else "Add override…"
	_reset.visible = has_line and has_overrides(line)
	if not has_line:
		_updating = false
		return
	_fill_speakers()
	_fill_boxes()
	_display_name.text = line.display_name_override
	_variant.text = String(line.visual_variant)
	if _placement != null:
		_placement.edited_resource = line.placement
	_placement_editor.set("editor_plugin", editor_plugin)
	_placement_editor.call("edit_anchor", line.placement)
	_speed.value = line.characters_per_second
	if _voice != null:
		_voice.edited_resource = line.voice_clip
	_event_id.text = String(line.event_id)
	_event_blocking.button_pressed = line.event_blocking
	_payload.text = JSON.stringify(line.event_payload)
	_line_id.text = String(line.line_id)
	_updating = false


func _refresh_field_visibility() -> void:
	var active := {
		"speaker": line != null and line.speaker_mode != TalkLine.SpeakerMode.INHERIT,
		"display_name_override": line != null and not line.display_name_override.is_empty(),
		"visual_variant": line != null and not line.visual_variant.is_empty(),
		"dialogue_box": line != null and line.dialogue_box != null,
		"placement": line != null and line.placement != null,
		"characters_per_second": line != null and line.characters_per_second > 0.0,
		"voice_clip": line != null and line.voice_clip != null,
		"event_id": line != null and not line.event_id.is_empty(),
		"event_blocking": line != null and line.event_blocking,
		"event_payload": line != null and line.event_payload != null,
		"line_id": line != null and not line.line_id.is_empty(),
	}
	for key in _field_rows:
		(_field_rows[key] as Control).visible = _show_all or bool(active.get(key, false))
		var reset := _reset_buttons.get(key) as Button
		if reset != null:
			reset.visible = bool(active.get(key, false))
	var groups := {
		"identity": ["speaker", "display_name_override", "visual_variant"],
		"presentation": ["dialogue_box", "placement", "characters_per_second"],
		"audio": ["voice_clip"],
		"event": ["event_id", "event_blocking", "event_payload"],
		"advanced": ["line_id"],
	}
	for group in groups:
		var visible := false
		for key in groups[group]:
			visible = visible or _show_all or bool(active.get(key, false))
		(_section_rows[group] as Control).visible = visible
	_settings.visible = line != null and (_show_all or has_overrides(line))
	var speaker_button := _manager_buttons.get("speaker") as Button
	if speaker_button != null:
		var resolved_speaker := component.resolve_speaker(line, conversation) if component != null else null
		speaker_button.disabled = resolved_speaker == null
	var box_button := _manager_buttons.get("dialogue_box") as Button
	if box_button != null:
		box_button.disabled = component == null or component.resolve_dialogue_box(line, conversation) == null


static func has_overrides(value: TalkLine) -> bool:
	if value == null:
		return false
	return value.speaker_mode != TalkLine.SpeakerMode.INHERIT \
		or value.dialogue_box != null \
		or value.placement != null \
		or not value.display_name_override.is_empty() \
		or not value.visual_variant.is_empty() \
		or value.characters_per_second > 0.0 \
		or value.voice_clip != null \
		or not value.event_id.is_empty() \
		or value.event_blocking \
		or value.event_payload != null \
		or not value.line_id.is_empty()


static func describe(value: TalkLine, owner: TalkConversation) -> String:
	if value == null:
		return "Select a line to inspect its exceptions."
	var count := override_count(value)
	if count == 0:
		return "Uses every conversation default."
	return "%d exception%s to this conversation's defaults." % [count, "" if count == 1 else "s"]


static func override_count(value: TalkLine) -> int:
	if value == null:
		return 0
	var count := 0
	if value.speaker_mode != TalkLine.SpeakerMode.INHERIT: count += 1
	if value.dialogue_box != null: count += 1
	if value.placement != null: count += 1
	if not value.display_name_override.is_empty(): count += 1
	if not value.visual_variant.is_empty(): count += 1
	if value.characters_per_second > 0.0: count += 1
	if value.voice_clip != null: count += 1
	if not value.event_id.is_empty(): count += 1
	if value.event_payload != null: count += 1
	if value.event_blocking: count += 1
	if not value.line_id.is_empty(): count += 1
	return count


func _fill_speakers() -> void:
	_speaker.clear()
	_speaker.add_item("Inherit · %s" % _speaker_label(conversation.default_speaker), SPEAKER_INHERIT)
	_speaker.add_item("None · narrator", SPEAKER_NONE)
	if component != null and not component.speakers.is_empty():
		_speaker.add_separator()
		for index in component.speakers.size():
			_speaker.add_item(_speaker_label(component.speakers[index]), SPEAKER_FIRST + index)
	var wanted := SPEAKER_INHERIT
	if line.speaker_mode == TalkLine.SpeakerMode.NONE:
		wanted = SPEAKER_NONE
	elif line.speaker_mode == TalkLine.SpeakerMode.SPEAKER and component != null:
		var at := component.speakers.find(line.speaker)
		wanted = SPEAKER_FIRST + at if at >= 0 else SPEAKER_INHERIT
	_speaker.selected = _speaker.get_item_index(wanted)


func _fill_boxes() -> void:
	_box.clear()
	_box.add_item("Inherit · %s" % _box_name(conversation.default_dialogue_box), BOX_INHERIT)
	if component != null and not component.dialogue_boxes.is_empty():
		_box.add_separator()
		for index in component.dialogue_boxes.size():
			_box.add_item(_box_name(component.dialogue_boxes[index]), BOX_FIRST + index)
	var at := component.dialogue_boxes.find(line.dialogue_box) if component != null else -1
	_box.selected = _box.get_item_index(BOX_FIRST + at if at >= 0 else BOX_INHERIT)


static func _speaker_label(value: TalkSpeaker) -> String:
	if value == null:
		return "Narrator"
	if not value.display_name.is_empty():
		return value.display_name
	if not value.speaker_id.is_empty():
		return String(value.speaker_id)
	return "Unnamed speaker"


static func _box_name(value: TalkBoxTemplate) -> String:
	if value == null:
		return "Classic Panel fallback"
	if not value.resource_name.is_empty():
		return value.resource_name
	if not value.resource_path.is_empty():
		return value.resource_path.get_file().get_basename().capitalize()
	return "Local box"


func _assign(property: StringName, value: Variant) -> void:
	if _updating or line == null or line.get(property) == value:
		return
	_commit("Change line %s" % String(property).replace("_", " "), [{
		"property": property, "value": value,
	}])


func _commit(action: String, operations: Array[Dictionary]) -> void:
	if line == null or operations.is_empty():
		return
	if Engine.is_editor_hint() and editor_plugin != null:
		var undo := editor_plugin.get_undo_redo()
		undo.create_action(action, UndoRedo.MERGE_DISABLE, line)
		for operation in operations:
			undo.add_do_property(line, operation["property"], operation["value"])
			undo.add_undo_property(line, operation["property"], line.get(operation["property"]))
		undo.add_do_method(self, &"_after_mutation")
		undo.add_undo_method(self, &"_after_mutation")
		undo.commit_action()
		return
	for operation in operations:
		line.set(operation["property"], operation["value"])
	_after_mutation()


func _after_mutation() -> void:
	if line != null:
		line.emit_changed()
	changed.emit()
	refresh()


## Asks for confirmation, then clears every exception on the line, including
## its event and line id.
func _confirm_reset_overrides() -> void:
	if line == null or not has_overrides(line):
		return
	if not Engine.is_editor_hint():
		_reset_overrides()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset this line?"
	dialog.dialog_text = reset_warning(line, line_index)
	dialog.ok_button_text = "Reset"
	dialog.confirmed.connect(func() -> void:
		_reset_overrides()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 140))


## The confirmation text describing what Reset clears on [param value], the
## line at [param index].
static func reset_warning(value: TalkLine, index: int) -> String:
	var count := override_count(value)
	var text := "Line %d has %d exception%s. Reset clears %s, so the line uses the conversation's defaults." % [
		index + 1, count, "" if count == 1 else "s", "it" if count == 1 else "all of them"]
	var relied_on: Array[String] = []
	if not value.event_id.is_empty():
		relied_on.append("event \"%s\"" % value.event_id)
	if not value.line_id.is_empty():
		relied_on.append("line id \"%s\"" % value.line_id)
	if not relied_on.is_empty():
		text += "\n\nThat includes its %s, which game code may rely on." % " and ".join(relied_on)
	var undo := "⌘Z" if OS.get_name() == "macOS" else "Ctrl+Z"
	return text + "\n\nUndo (%s) brings everything back." % undo


func _reset_overrides() -> void:
	if line == null or not has_overrides(line):
		return
	_show_all = false
	_commit("Reset line exceptions", [
		{"property": &"speaker_mode", "value": TalkLine.SpeakerMode.INHERIT},
		{"property": &"speaker", "value": null},
		{"property": &"speaker_id", "value": &""},
		{"property": &"dialogue_box", "value": null},
		{"property": &"placement", "value": null},
		{"property": &"display_name_override", "value": ""},
		{"property": &"visual_variant", "value": &""},
		{"property": &"characters_per_second", "value": 0.0},
		{"property": &"voice_clip", "value": null},
		{"property": &"event_id", "value": &""},
		{"property": &"event_payload", "value": null},
		{"property": &"event_blocking", "value": false},
		{"property": &"line_id", "value": &""},
	])


func _reset_property(key: String) -> void:
	if line == null:
		return
	match key:
		"speaker":
			_commit("Reset line speaker", [
				{"property": &"speaker_mode", "value": TalkLine.SpeakerMode.INHERIT},
				{"property": &"speaker", "value": null},
				{"property": &"speaker_id", "value": &""},
			])
		"display_name_override": _assign(&"display_name_override", "")
		"visual_variant": _assign(&"visual_variant", &"")
		"dialogue_box": _assign(&"dialogue_box", null)
		"placement": _assign(&"placement", null)
		"characters_per_second": _assign(&"characters_per_second", 0.0)
		"voice_clip": _assign(&"voice_clip", null)
		"event_id": _assign(&"event_id", &"")
		"event_blocking": _assign(&"event_blocking", false)
		"event_payload": _assign(&"event_payload", null)
		"line_id": _assign(&"line_id", &"")


func _navigate_manager(section: String) -> void:
	if component == null or line == null:
		return
	var resource: Resource
	if section == "speakers":
		resource = component.resolve_speaker(line, conversation)
	else:
		resource = component.resolve_dialogue_box(line, conversation)
	if resource != null:
		navigate_resource.emit(section, resource)


func focus_field(field: String) -> void:
	if not _field_rows.has(field):
		return
	_show_all = true
	refresh()
	var controls := {
		"speaker": _speaker,
		"display_name_override": _display_name,
		"visual_variant": _variant,
		"dialogue_box": _box,
		"placement": _placement_editor,
		"characters_per_second": _speed,
		"voice_clip": _voice,
		"event_id": _event_id,
		"event_blocking": _event_blocking,
		"event_payload": _payload,
		"line_id": _line_id,
	}
	var control := controls.get(field) as Control
	if control != null:
		control.grab_focus()


func _on_speaker(index: int) -> void:
	if _updating or line == null:
		return
	var id := _speaker.get_item_id(index)
	var mode := TalkLine.SpeakerMode.INHERIT
	var speaker: TalkSpeaker
	if id == SPEAKER_INHERIT:
		mode = TalkLine.SpeakerMode.INHERIT
	elif id == SPEAKER_NONE:
		mode = TalkLine.SpeakerMode.NONE
	else:
		var at := id - SPEAKER_FIRST
		if component == null or at < 0 or at >= component.speakers.size():
			return
		mode = TalkLine.SpeakerMode.SPEAKER
		speaker = component.speakers[at]
	_commit("Change line speaker", [
		{"property": &"speaker_mode", "value": mode},
		{"property": &"speaker", "value": speaker},
		{"property": &"speaker_id", "value": &""},
	])


func _on_box(index: int) -> void:
	if _updating or line == null:
		return
	var id := _box.get_item_id(index)
	var value: TalkBoxTemplate = null if id == BOX_INHERIT else component.dialogue_boxes[id - BOX_FIRST]
	_assign(&"dialogue_box", value)


func _on_display_name(value: String) -> void: _assign(&"display_name_override", value)
func _on_variant(value: String) -> void: _assign(&"visual_variant", StringName(value))
func _on_placement(value: Resource) -> void: _assign(&"placement", value as TalkAnchor)
func _on_placement_edited() -> void:
	if _updating or line == null:
		return
	_after_mutation()
func _on_speed(value: float) -> void: _assign(&"characters_per_second", value)
func _on_voice(value: Resource) -> void: _assign(&"voice_clip", value as AudioStream)
func _on_event_id(value: String) -> void: _assign(&"event_id", StringName(value))
func _on_event_blocking(value: bool) -> void: _assign(&"event_blocking", value)
func _on_line_id(value: String) -> void: _assign(&"line_id", StringName(value))


func _on_payload_committed() -> void:
	if _updating or line == null:
		return
	var parsed := JSON.parse_string(_payload.text)
	if parsed == null and _payload.text.strip_edges() not in ["", "null"]:
		_summary.text = "Event payload is not valid JSON. The previous value was kept."
		return
	_assign(&"event_payload", parsed)
