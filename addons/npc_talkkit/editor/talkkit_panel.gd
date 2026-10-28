@tool
extends VBoxContainer

signal line_selected(conversation: TalkConversation, line: TalkLine, index: int)
## Emitted when the preview cursor moves or playback starts or stops.
## [param animate] is true while Play is running.
signal preview_line(conversation: TalkConversation, line: TalkLine, index: int, animate: bool)
signal changed
signal navigate_manager(section: String, resource: Resource)

## Conversation editor in the TalkKit workspace: the conversation list, text-first
## line rows and the conversation defaults. Lines and conversations choose
## speakers and dialogue boxes; their own managers edit them.

const ROW_HEIGHT := 30
enum RefreshMode { NONE, LINES, FULL }

enum { MENU_RENAME, MENU_DUPLICATE, MENU_PROMOTE, MENU_DELETE }
enum { LINE_INSPECT, LINE_UP, LINE_DOWN, LINE_DUPLICATE, LINE_DELETE }
enum { PLACEMENT_BOX, PLACEMENT_SCREEN, PLACEMENT_FOLLOW, PLACEMENT_EDIT }
enum { BULK_DUPLICATE = 10, BULK_DELETE, BULK_CLEAR, BULK_SPEAKER_INHERIT, BULK_SPEAKER_NONE,
	BULK_BOX_INHERIT, BULK_PLACEMENT_INHERIT, BULK_PLACEMENT_SCREEN, BULK_PLACEMENT_FOLLOW }
const BULK_SPEAKER_FIRST := 1000
const BULK_BOX_FIRST := 2000

## Ids in the per-line dropdowns. Collection entries start at FIRST.
const SPEAKER_INHERIT := 0
const SPEAKER_NONE := 1
const SPEAKER_FIRST := 2
const BOX_INHERIT := 0
const BOX_FIRST := 1
const DEFAULT_CREATE := 8000
const DEFAULT_MANAGE := 8001
const DEFAULT_BROWSE := 8002

const CollectionSummary := preload("res://addons/npc_talkkit/editor/talkkit_collection_summary.gd")
const EffectiveRow := preload("res://addons/npc_talkkit/editor/talkkit_effective_row.gd")
const PlacementEditor := preload("res://addons/npc_talkkit/editor/talkkit_placement_editor.gd")
const LineDragHandle := preload("res://addons/npc_talkkit/editor/talkkit_line_drag_handle.gd")

var component: NPCTalkKit
var editor_plugin: EditorPlugin
var _conversations_split: HSplitContainer

## Play / Next cursor; the Live preview renders the line it points at.
var _transport := TalkKitPreviewTransport.new()
var _preview_status: Label
var _play_button: Button

var _conversations: ItemList
var _left_title: Label
var _search: LineEdit
var _selection_meta: Label
var _conversation_menu: MenuButton
var _left_panel: Control
var _right_panel: Control
var _list_button: Button
var _narrow_navigation := false
var _line_scroll: ScrollContainer
var _conversation_empty: CenterContainer
var _empty_title: Label
var _empty_copy: Label
var _lines_box: VBoxContainer
var _continue_button: Button
var _lines_title: LineEdit
var _empty_hint: Label
var _empty_action: Button
var _add_line_button: Button
var _bulk_menu: MenuButton
var _bulk_selected: Array[TalkLine] = []
var _speakers_box: VBoxContainer
var _editing_row := -1


func _ready() -> void:
	_build()
	_transport.changed.connect(_on_preview_changed)
	refresh()


func _exit_tree() -> void:
	_transport.stop()


#region Construction

func _build() -> void:
	_build_conversations()


func _build_conversations() -> Control:
	var split := HSplitContainer.new()
	split.split_offset = _saved_split("conversation_list", 220)
	split.dragged.connect(_save_split.bind("conversation_list"))
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_conversations_split = split

	# Tint the sidebar from the editor's base colour so it stands apart from the
	# panel behind it and follows the theme.
	var left_panel := PanelContainer.new()
	_left_panel = left_panel
	left_panel.custom_minimum_size.x = 210
	left_panel.add_theme_stylebox_override("panel", _sidebar_style())
	split.add_child(left_panel)

	var left := VBoxContainer.new()
	left_panel.add_child(left)

	var left_header := HBoxContainer.new()
	left.add_child(left_header)

	_left_title = Label.new()
	_left_title.text = "Conversations"
	_left_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_title.add_theme_font_size_override("font_size", 12)
	left_header.add_child(_left_title)

	_button(left_header, "+", "New conversation", _add_conversation)

	_conversation_menu = MenuButton.new()
	_conversation_menu.text = "⋮"
	_conversation_menu.tooltip_text = "Actions for the selected conversation"
	var menu := _conversation_menu.get_popup()
	menu.add_item("Rename…", MENU_RENAME)
	menu.add_item("Duplicate", MENU_DUPLICATE)
	menu.add_item("Save to Library", MENU_PROMOTE)
	menu.add_separator()
	menu.add_item("Delete", MENU_DELETE)
	menu.id_pressed.connect(_on_conversation_menu)
	left_header.add_child(_conversation_menu)

	_search = LineEdit.new()
	_search.placeholder_text = "Search conversations…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_changed)
	left.add_child(_search)

	_conversations = ItemList.new()
	_conversations.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_conversations.max_text_lines = 2
	_conversations.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_conversations.item_selected.connect(_on_conversation_selected)
	_conversations.item_activated.connect(_rename_conversation)
	left.add_child(_conversations)
	_selection_meta = Label.new()
	_selection_meta.add_theme_font_size_override("font_size", 11)
	_selection_meta.modulate.a = 0.65
	_selection_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_selection_meta)


	var right_panel := MarginContainer.new()
	_right_panel = right_panel
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right_panel)

	var right_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		right_margin.add_theme_constant_override("margin_" + side, 6)
	right_panel.add_child(right_margin)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_child(right)

	var right_header := HBoxContainer.new()
	right.add_child(right_header)
	_list_button = Button.new()
	_list_button.text = "‹ Conversations"
	_list_button.tooltip_text = "Return to the conversation list"
	_list_button.visible = false
	_list_button.pressed.connect(_show_narrow_list)
	right_header.add_child(_list_button)
	_lines_title = LineEdit.new()
	_lines_title.placeholder_text = "Conversation id"
	_lines_title.tooltip_text = "Rename this conversation in place"
	_lines_title.add_theme_font_size_override("font_size", 12)
	_lines_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines_title.text_submitted.connect(_submit_conversation_id)
	_lines_title.focus_exited.connect(func() -> void: _commit_conversation_id(_lines_title.text))
	right_header.add_child(_lines_title)
	_play_button = _button(right_header, "▶ Play",
		"Play the conversation; press again to stop and clear it",
		_transport.toggle_play)
	_add_line_button = _button(right_header, "+ Line", "Append a line (Enter on the last line does this too)", _add_line)
	_bulk_menu = MenuButton.new()
	_bulk_menu.text = "Selected"
	_bulk_menu.visible = false
	_bulk_menu.get_popup().id_pressed.connect(_on_bulk_action)
	right_header.add_child(_bulk_menu)
	_button(right_header, "↓ Next", "Next line, wrapping to the first at the end",
		_transport.next)

	_preview_status = Label.new()
	_preview_status.add_theme_font_size_override("font_size", 11)
	_preview_status.custom_minimum_size.x = 90
	right_header.add_child(_preview_status)

	_button(right_header, "Validate",
		"Check every NPCTalkKit in this scene, together with the library",
		_validate_scene)

	_line_scroll = ScrollContainer.new()
	_line_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_line_scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_scroll.add_child(column)

	_lines_box = VBoxContainer.new()
	_lines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_lines_box)
	_continue_button = Button.new()
	_continue_button.text = "+ Continue writing"
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_continue_button.pressed.connect(_add_line)
	column.add_child(_continue_button)

	_speakers_box = VBoxContainer.new()
	_speakers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_speakers_box)

	_conversation_empty = CenterContainer.new()
	_conversation_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_conversation_empty)
	var empty_column := VBoxContainer.new()
	empty_column.custom_minimum_size.x = 360
	empty_column.add_theme_constant_override("separation", 8)
	_conversation_empty.add_child(empty_column)
	_empty_title = Label.new()
	_empty_title.text = "Create the first conversation"
	_empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_title.add_theme_font_size_override("font_size", 18)
	empty_column.add_child(_empty_title)
	_empty_copy = Label.new()
	_empty_copy.text = "TalkKit will prepare a local Classic Panel and the first empty line, then place the cursor where you can start typing."
	_empty_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_copy.modulate.a = 0.72
	empty_column.add_child(_empty_copy)
	_empty_action = Button.new()
	_empty_action.text = "Create first conversation"
	_empty_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_action.pressed.connect(_add_conversation)
	empty_column.add_child(_empty_action)

	_empty_hint = Label.new()
	_empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_hint.add_theme_font_size_override("font_size", 11)
	_empty_hint.modulate.a = 0.7
	right.add_child(_empty_hint)
	return split


func _saved_split(key: String, fallback: int) -> int:
	if not Engine.is_editor_hint():
		return fallback
	var settings := EditorInterface.get_editor_settings()
	var path := "npc_talkkit/layout/%s" % key
	return int(settings.get_setting(path)) if settings.has_setting(path) else fallback


func _save_split(offset: int, key: String) -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_setting("npc_talkkit/layout/%s" % key, offset)


## Sidebar style: a tint and a right-hand edge derived from the editor theme.
func _sidebar_style() -> StyleBoxFlat:
	var base := Color(0.13, 0.14, 0.17)
	if Engine.is_editor_hint():
		var editor_theme := EditorInterface.get_editor_theme()
		if editor_theme != null and editor_theme.has_color("base_color", "Editor"):
			base = editor_theme.get_color("base_color", "Editor")

	var box := StyleBoxFlat.new()
	var dark := base.get_luminance() < 0.5
	box.bg_color = base.darkened(0.18) if dark else base.darkened(0.06)
	box.border_color = base.lightened(0.18) if dark else base.darkened(0.22)
	box.border_width_right = 1
	box.content_margin_left = 6.0
	box.content_margin_top = 6.0
	box.content_margin_right = 6.0
	box.content_margin_bottom = 6.0
	return box


func _button(parent: Control, text: String, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

#endregion


#region Refresh

func refresh() -> void:
	if _conversations == null:
		return
	var previously_selected := _current_conversation()
	_conversations.clear()
	if component == null:
		_left_title.text = "Conversations"
		_set_hint("Select an NPCTalkKit node to edit its dialogue.")
		_refresh_lines()
		return
	_left_title.text = "Conversations"
	var seen_names: Dictionary = {}
	var row_to_restore := -1
	var query := _search.text.strip_edges().to_lower()
	for index in component.conversations.size():
		var conversation := component.conversations[index]
		if conversation == null:
			continue
		var title := String(conversation.conversation_id)
		if title.is_empty():
			title = "(unnamed)"
		if not query.is_empty() and not title.to_lower().contains(query):
			continue
		var scope := "Shared" if _is_library_file(conversation) else "Local"
		var label := title
		var conversation_report := TalkValidator.validate_conversation(conversation, component.speakers)
		conversation_report.merge(TalkValidator.validate_against_collection(
			conversation, component.speakers, component.dialogue_boxes))
		if conversation_report.error_count() > 0:
			label += "  ●"
		elif conversation_report.warning_count() > 0:
			label += "  ▲"
		if _is_library_file(conversation):
			label += "  ↗"
		# play() finds the first match, so later duplicates can never run.
		if seen_names.has(label_key(conversation)):
			label += "   ⚠ unreachable — name already used"
		seen_names[label_key(conversation)] = true
		_conversations.add_item(label)
		var tooltip := "%s · %s to this node" % [title, scope]
		if not conversation_report.issues.is_empty():
			tooltip += "\n%s" % "\n".join(conversation_report.issues.map(
				func(issue: TalkValidationIssue) -> String: return issue.message))
		_conversations.set_item_tooltip(_conversations.item_count - 1, tooltip)
		if conversation == previously_selected:
			row_to_restore = _conversations.item_count - 1
		# Empty array elements have no row, so rows map to array indices.
		_conversations.set_item_metadata(_conversations.item_count - 1, index)
	if _conversations.item_count > 0:
		_conversations.select(row_to_restore if row_to_restore >= 0 else 0)
	_conversation_menu.disabled = _conversations.item_count == 0
	_refresh_lines()


func _on_search_changed(_value: String) -> void:
	refresh()


func _on_conversation_selected(_index: int) -> void:
	_refresh_lines()
	if _narrow_navigation:
		_show_narrow_editor()


func set_narrow_navigation(enabled: bool) -> void:
	_narrow_navigation = enabled
	if _left_panel == null or _right_panel == null or _list_button == null:
		return
	_list_button.visible = enabled
	if enabled:
		_show_narrow_editor()
	else:
		_left_panel.visible = true
		_right_panel.visible = true


func _show_narrow_list() -> void:
	if not _narrow_navigation:
		return
	_left_panel.visible = true
	_right_panel.visible = false


func _show_narrow_editor() -> void:
	if not _narrow_navigation:
		return
	_left_panel.visible = false
	_right_panel.visible = true


func _commit_conversation_id(value: String) -> void:
	var conversation := _current_conversation()
	if conversation == null:
		return
	var wanted := value.strip_edges()
	if wanted.is_empty():
		_set_hint("Conversation id cannot be empty.")
		_lines_title.text = String(conversation.conversation_id)
		return
	for candidate in component.conversations:
		if candidate != null and candidate != conversation and String(candidate.conversation_id) == wanted:
			_set_hint("Conversation id '%s' is already used on this node." % wanted)
			_lines_title.text = String(conversation.conversation_id)
			return
	if String(conversation.conversation_id) == wanted:
		return
	_commit("Rename conversation", [{
		"object": conversation, "property": &"conversation_id", "value": StringName(wanted),
	}], RefreshMode.FULL)


func _submit_conversation_id(value: String) -> void:
	_commit_conversation_id(value)
	_focus_row(0)


func _refresh_lines() -> void:
	_empty_action.visible = false
	_continue_button.visible = false
	_line_scroll.visible = true
	_conversation_empty.visible = false
	for child in _lines_box.get_children():
		child.queue_free()
	for child in _speakers_box.get_children():
		child.queue_free()
	var conversation := _current_conversation()
	_add_line_button.disabled = conversation == null

	if component == null:
		_selection_meta.text = ""
		_line_scroll.visible = false
		return
	if conversation == null:
		_selection_meta.text = ""
		_lines_title.text = ""
		_lines_title.editable = false
		_line_scroll.visible = false
		_conversation_empty.visible = true
		var filtered := not component.conversations.is_empty()
		_empty_title.text = "No conversations match" if filtered else "Create the first conversation"
		_empty_copy.text = (
			"Try another search term."
			if filtered else
			"TalkKit will prepare a local Classic Panel and the first empty line, then place the cursor where you can start typing."
		)
		_set_hint("say() still works without authored conversations." if not filtered else "")
		_empty_action.visible = not filtered
		return
	var event_count := 0
	for candidate in conversation.lines:
		if candidate != null and not candidate.event_id.is_empty():
			event_count += 1
	_selection_meta.text = "%d line%s%s · %s" % [
		conversation.lines.size(),
		"" if conversation.lines.size() == 1 else "s",
		" · %d event%s" % [event_count, "" if event_count == 1 else "s"] if event_count > 0 else "",
		"Shared" if _is_library_file(conversation) else "Local",
	]

	_lines_title.editable = true
	_lines_title.text = String(conversation.conversation_id)
	_lines_title.tooltip_text = "%d line%s · rename in place" % [
		conversation.lines.size(), "" if conversation.lines.size() == 1 else "s"]
	_lines_box.add_child(_make_defaults_row(conversation))
	_refresh_preview()
	if not conversation.lines.is_empty():
		_editing_row = clampi(_editing_row, 0, conversation.lines.size() - 1)
	for index in conversation.lines.size():
		_lines_box.add_child(_make_row(conversation, index))
	_continue_button.visible = not conversation.lines.is_empty()
	if not conversation.lines.is_empty():
		_select_line(_editing_row)
	else:
		_editing_row = -1
		line_selected.emit(conversation, null, -1)
	_rebuild_bulk_menu()

	if conversation.lines.is_empty():
		_set_hint("No lines yet. Press + Line and start typing.")
	elif _is_library_file(conversation):
		_set_hint("This conversation is a library file — edits here affect every NPC using it.")
	else:
		_set_hint("Enter on the last line adds another. Select a line to edit its exceptions.")


## The conversation defaults row, shown above the lines.
func _make_defaults_row(conversation: TalkConversation) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT

	var title := Label.new()
	title.text = "Defaults"
	title.custom_minimum_size.x = 22 + 4
	title.add_theme_font_size_override("font_size", 11)
	row.add_child(title)

	var speaker := OptionButton.new()
	speaker.custom_minimum_size.x = 132
	_fits_its_box(speaker)
	speaker.tooltip_text = "Who speaks the lines that say nothing about it"
	speaker.add_theme_font_size_override("font_size", 11)
	speaker.add_item("None · narrator", SPEAKER_NONE)
	var speakers := speaker_choices(component)
	for index in speakers.size():
		speaker.add_item(speaker_display(speakers[index]), SPEAKER_FIRST + index)
	speaker.add_separator()
	speaker.add_item("Create new…", DEFAULT_CREATE)
	speaker.add_item("Manage speakers…", DEFAULT_MANAGE)
	speaker.add_item("Browse…", DEFAULT_BROWSE)
	var chosen := speakers.find(conversation.default_speaker)
	speaker.selected = speaker.get_item_index(
		SPEAKER_FIRST + chosen if chosen >= 0 else SPEAKER_NONE)
	speaker.item_selected.connect(func(at: int) -> void:
		_on_default_reference_action(speaker.get_item_id(at), conversation, true))
	row.add_child(speaker)

	var box := OptionButton.new()
	box.custom_minimum_size.x = 132
	_fits_its_box(box)
	box.tooltip_text = "Which box paints the lines that say nothing about it"
	box.add_theme_font_size_override("font_size", 11)
	box.add_item("None set", BOX_INHERIT)
	var boxes := box_choices(component)
	for index in boxes.size():
		box.add_item(
			CollectionSummary.entry_name(boxes[index], CollectionSummary.Kind.BOXES),
			BOX_FIRST + index)
	box.add_separator()
	box.add_item("Create new…", DEFAULT_CREATE)
	box.add_item("Manage dialogue boxes…", DEFAULT_MANAGE)
	box.add_item("Browse…", DEFAULT_BROWSE)
	var chosen_box := boxes.find(conversation.default_dialogue_box)
	box.selected = box.get_item_index(
		BOX_FIRST + chosen_box if chosen_box >= 0 else BOX_INHERIT)
	box.item_selected.connect(func(at: int) -> void:
		_on_default_reference_action(box.get_item_id(at), conversation, false))
	row.add_child(box)

	# Readable label instead of the picker's "<empty>".
	var placement := MenuButton.new()
	placement.text = describe_default_placement(conversation)
	placement.custom_minimum_size.x = 150
	placement.clip_text = true
	placement.alignment = HORIZONTAL_ALIGNMENT_LEFT
	placement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement.add_theme_font_size_override("font_size", 11)
	placement.tooltip_text = "Where these lines appear"
	var placement_menu := placement.get_popup()
	placement_menu.add_item("Use dialogue box placement", PLACEMENT_BOX)
	placement_menu.add_separator()
	placement_menu.add_item("Screen placement", PLACEMENT_SCREEN)
	placement_menu.add_item("Follow target", PLACEMENT_FOLLOW)
	if conversation.default_placement != null:
		placement_menu.add_separator()
		placement_menu.add_item("Advanced placement properties…", PLACEMENT_EDIT)
	placement_menu.id_pressed.connect(_on_default_placement_action.bind(conversation))
	row.add_child(placement)

	_button(row, "⋮", "Open advanced conversation properties",
		_inspect_conversation.bind(conversation))
	# Keeps this row's ⋮ aligned with the line rows below.
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 26
	row.add_child(spacer)
	return _framed(row)


## The conversation's default placement, described in words.
static func describe_default_placement(conversation: TalkConversation) -> String:
	if conversation == null or conversation.default_placement == null:
		return "Box's own placement"
	return EffectiveRow.describe_anchor(conversation.default_placement)


func _inspect_conversation(conversation: TalkConversation) -> void:
	if Engine.is_editor_hint() and conversation != null:
		EditorInterface.edit_resource(conversation)


func _on_default_reference_action(id: int, conversation: TalkConversation, speaker_kind: bool) -> void:
	if id == DEFAULT_MANAGE:
		navigate_manager.emit("speakers" if speaker_kind else "boxes",
			conversation.default_speaker if speaker_kind else conversation.default_dialogue_box)
		_refresh_lines()
		return
	if id == DEFAULT_CREATE:
		if speaker_kind:
			var speaker := TalkSpeaker.new()
			speaker.display_name = "New speaker"
			var entries := component.speakers.duplicate()
			entries.append(speaker)
			_commit("Create conversation speaker", [
				{"object": component, "property": &"speakers", "value": entries},
				{"object": conversation, "property": &"default_speaker", "value": speaker},
			], RefreshMode.FULL)
			navigate_manager.emit("speakers", speaker)
		else:
			var box := NPCTalkKit.default_template().duplicate(true) as TalkBoxTemplate
			box.resource_name = "Classic Panel"
			var entries := component.dialogue_boxes.duplicate()
			entries.append(box)
			_commit("Create conversation dialogue box", [
				{"object": component, "property": &"dialogue_boxes", "value": entries},
				{"object": conversation, "property": &"default_dialogue_box", "value": box},
			], RefreshMode.FULL)
			navigate_manager.emit("boxes", box)
		return
	if id == DEFAULT_BROWSE:
		_browse_default_reference(conversation, speaker_kind)
		_refresh_lines()
		return
	if speaker_kind:
		_choose_default_speaker(id, conversation)
	else:
		_choose_default_box(id, conversation)


func _browse_default_reference(conversation: TalkConversation, speaker_kind: bool) -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Speaker" if speaker_kind else "Dialogue box")
	dialog.file_selected.connect(func(path: String) -> void:
		var resource := load(path)
		if speaker_kind and resource is TalkSpeaker:
			var entries := component.speakers.duplicate()
			if not entries.has(resource): entries.append(resource)
			_commit("Use shared conversation speaker", [
				{"object": component, "property": &"speakers", "value": entries},
				{"object": conversation, "property": &"default_speaker", "value": resource},
			], RefreshMode.FULL)
		elif not speaker_kind and resource is TalkBoxTemplate:
			var entries := component.dialogue_boxes.duplicate()
			if not entries.has(resource): entries.append(resource)
			_commit("Use shared conversation dialogue box", [
				{"object": component, "property": &"dialogue_boxes", "value": entries},
				{"object": conversation, "property": &"default_dialogue_box", "value": resource},
			], RefreshMode.FULL)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_file_dialog()


## Tints the defaults row so it reads as a header rather than a line.
func _framed(row: Control) -> Control:
	var frame := PanelContainer.new()
	var base := Color(0.13, 0.14, 0.17)
	if Engine.is_editor_hint():
		var editor_theme := EditorInterface.get_editor_theme()
		if editor_theme != null and editor_theme.has_color("base_color", "Editor"):
			base = editor_theme.get_color("base_color", "Editor")
	var style := StyleBoxFlat.new()
	var dark := base.get_luminance() < 0.5
	style.bg_color = base.lightened(0.06) if dark else base.darkened(0.04)
	style.border_color = base.lightened(0.16) if dark else base.darkened(0.2)
	style.border_width_bottom = 1
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(row)
	return frame


func _choose_default_speaker(id: int, conversation: TalkConversation) -> void:
	var speakers := speaker_choices(component)
	var at := id - SPEAKER_FIRST
	var value: TalkSpeaker = speakers[at] if at >= 0 and at < speakers.size() else null
	_commit("Change conversation speaker", [{
		"object": conversation, "property": &"default_speaker", "value": value,
	}], RefreshMode.LINES)


func _choose_default_box(id: int, conversation: TalkConversation) -> void:
	var boxes := box_choices(component)
	var at := id - BOX_FIRST
	var value: TalkBoxTemplate = boxes[at] if at >= 0 and at < boxes.size() else null
	_commit("Change conversation dialogue box", [{
		"object": conversation, "property": &"default_dialogue_box", "value": value,
	}], RefreshMode.LINES)


func _choose_default_placement(value: Resource, conversation: TalkConversation) -> void:
	_commit("Change conversation placement", [{
		"object": conversation,
		"property": &"default_placement",
		"value": value as TalkAnchor,
	}], RefreshMode.LINES)


func _on_default_placement_action(id: int, conversation: TalkConversation) -> void:
	if id == PLACEMENT_EDIT:
		_open_placement_editor(conversation)
		return
	var value: TalkAnchor
	if id == PLACEMENT_SCREEN:
		value = TalkAnchor.new()
		value.mode = TalkAnchor.Mode.SCREEN
	elif id == PLACEMENT_FOLLOW:
		value = TalkAnchor.new()
		value.mode = TalkAnchor.Mode.NODE_FOLLOW
	_choose_default_placement(value, conversation)


func _open_placement_editor(conversation: TalkConversation) -> void:
	if conversation == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Conversation placement"
	dialog.ok_button_text = "Done"
	dialog.min_size = Vector2i(420, 590)
	var editor := PlacementEditor.new()
	editor.editor_plugin = editor_plugin
	editor.edit_anchor(conversation.default_placement)
	editor.replacement_requested.connect(func(anchor: TalkAnchor) -> void:
		_choose_default_placement(anchor, conversation)
		editor.edit_anchor(anchor))
	editor.changed.connect(func() -> void:
		changed.emit()
		_refresh_lines())
	# Advanced 3D makes the editor taller than many screens, so it scrolls.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(editor)
	dialog.add_child(scroll)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 620))


func _make_row(conversation: TalkConversation, index: int) -> Control:
	var line := conversation.lines[index]
	var frame := PanelContainer.new()
	frame.set_meta("talkkit_line_index", index)
	frame.add_theme_stylebox_override("panel", _line_style(index == _editing_row))
	# A click anywhere on the row picks the line, not only in its text.
	frame.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and index != _editing_row:
			_select_line(index))
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 68
	row.add_theme_constant_override("separation", 6)
	frame.add_child(row)

	var drag := LineDragHandle.new()
	drag.line_index = index
	drag.line_dropped.connect(_move_line_to)
	row.add_child(drag)
	var selected := CheckBox.new()
	selected.button_pressed = _bulk_selected.has(line)
	selected.tooltip_text = "Select this line for bulk editing"
	selected.toggled.connect(_toggle_bulk_line.bind(line))
	row.add_child(selected)

	var number := Label.new()
	number.text = "%d" % (index + 1)
	number.custom_minimum_size.x = 20
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.add_theme_font_size_override("font_size", 11)
	row.add_child(number)

	# Avatar button to change speaker; the resolved speaker sits above the text.
	var identity := speaker_label(component, conversation, line)
	var avatar := MenuButton.new()
	avatar.text = speaker_initial(identity)
	avatar.custom_minimum_size = Vector2(32, 32)
	avatar.tooltip_text = "Change speaker · %s" % ("Narrator" if identity == "—" else identity)
	avatar.add_theme_font_size_override("font_size", 12)
	_fill_speaker_popup(avatar.get_popup(), conversation, line)
	avatar.get_popup().id_pressed.connect(_choose_speaker.bind(line))
	row.add_child(avatar)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	# The override summary sits in the heading row, so every text box spans the
	# full row width.
	var heading := HBoxContainer.new()
	copy.add_child(heading)
	var identity_label := Label.new()
	identity_label.text = "Narrator" if identity == "—" else identity
	identity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_label.add_theme_font_size_override("font_size", 11)
	identity_label.modulate.a = 0.72 if identity == "—" else 1.0
	heading.add_child(identity_label)

	var edit := TextEdit.new()
	edit.text = line.text if line != null else ""
	edit.placeholder_text = "What this NPC says…"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(260, 46)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.text_changed.connect(func() -> void: _set_text(line, edit.text))
	edit.focus_entered.connect(_select_line.bind(index))
	copy.add_child(edit)

	var details := Button.new()
	details.text = line_summary(line) + _line_validation_marker(conversation, index)
	details.flat = true
	details.tooltip_text = "Show this line's exceptions and event"
	details.add_theme_font_size_override("font_size", 11)
	details.pressed.connect(_select_line.bind(index))
	heading.add_child(details)

	# Less frequent actions live behind one menu.
	var more := MenuButton.new()
	more.text = "⋮"
	more.tooltip_text = "More actions for this line"
	more.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var menu := more.get_popup()
	menu.add_item("Show details", LINE_INSPECT)
	menu.add_separator()
	menu.add_item("Move up", LINE_UP)
	menu.add_item("Move down", LINE_DOWN)
	menu.add_item("Duplicate", LINE_DUPLICATE)
	menu.add_separator()
	menu.add_item("Delete", LINE_DELETE)
	menu.id_pressed.connect(_on_line_menu.bind(index))
	row.add_child(more)
	edit.gui_input.connect(_on_text_input.bind(index, edit, avatar, more))
	return frame


func _line_validation_marker(conversation: TalkConversation, index: int) -> String:
	var report := TalkValidator.validate_conversation(conversation, component.speakers)
	var has_warning := false
	for issue in report.issues:
		if issue.line_index != index:
			continue
		if issue.severity == &"error":
			return " · ●"
		has_warning = true
	return " · ▲" if has_warning else ""


func _toggle_bulk_line(selected: bool, line: TalkLine) -> void:
	if selected and not _bulk_selected.has(line):
		_bulk_selected.append(line)
	elif not selected:
		_bulk_selected.erase(line)
	_rebuild_bulk_menu()


func _rebuild_bulk_menu() -> void:
	var conversation := _current_conversation()
	_bulk_selected = _bulk_selected.filter(func(value: TalkLine) -> bool:
		return is_instance_valid(value) and conversation != null and conversation.lines.has(value))
	if _bulk_menu == null:
		return
	_bulk_menu.visible = not _bulk_selected.is_empty()
	_bulk_menu.text = "%d selected" % _bulk_selected.size()
	var menu := _bulk_menu.get_popup()
	menu.clear()
	menu.add_item("Duplicate selected", BULK_DUPLICATE)
	menu.add_item("Delete selected", BULK_DELETE)
	menu.add_separator()
	menu.add_item("Speaker · inherit", BULK_SPEAKER_INHERIT)
	menu.add_item("Speaker · narrator", BULK_SPEAKER_NONE)
	for index in speaker_choices(component).size():
		menu.add_item("Speaker · %s" % speaker_display(speaker_choices(component)[index]), BULK_SPEAKER_FIRST + index)
	menu.add_separator()
	menu.add_item("Dialogue box · inherit", BULK_BOX_INHERIT)
	for index in box_choices(component).size():
		menu.add_item("Dialogue box · %s" % CollectionSummary.entry_name(
			box_choices(component)[index], CollectionSummary.Kind.BOXES), BULK_BOX_FIRST + index)
	menu.add_separator()
	menu.add_item("Placement · inherit", BULK_PLACEMENT_INHERIT)
	menu.add_item("Placement · screen", BULK_PLACEMENT_SCREEN)
	menu.add_item("Placement · follow target", BULK_PLACEMENT_FOLLOW)
	menu.add_separator()
	menu.add_item("Clear selection", BULK_CLEAR)


func _on_bulk_action(id: int) -> void:
	var conversation := _current_conversation()
	if conversation == null or _bulk_selected.is_empty():
		return
	if id == BULK_CLEAR:
		_bulk_selected.clear()
		_refresh_lines()
		return
	if id == BULK_DUPLICATE:
		var lines: Array[TalkLine] = []
		for source in conversation.lines:
			lines.append(source)
			if _bulk_selected.has(source):
				var copy := source.duplicate(true) as TalkLine
				copy.line_id = &""
				lines.append(copy)
		_commit("Duplicate selected dialogue lines", [{
			"object": conversation, "property": &"lines", "value": lines,
		}], RefreshMode.LINES)
		_bulk_selected.clear()
		return
	if id == BULK_DELETE:
		var count := _bulk_selected.size()
		_confirm("Delete %d lines?" % count,
			"The %d selected lines and everything on them — text, overrides and events — are removed from \"%s\"." % [
				count, conversation.conversation_id],
			"Delete", _delete_selected_lines.bind(conversation))
		return
	var operations: Array[Dictionary] = []
	for target in _bulk_selected:
		if id == BULK_SPEAKER_INHERIT or id == BULK_SPEAKER_NONE or id >= BULK_SPEAKER_FIRST and id < BULK_BOX_FIRST:
			var mode := TalkLine.SpeakerMode.INHERIT
			var speaker: TalkSpeaker
			if id == BULK_SPEAKER_NONE:
				mode = TalkLine.SpeakerMode.NONE
			elif id >= BULK_SPEAKER_FIRST:
				var at := id - BULK_SPEAKER_FIRST
				if at >= speaker_choices(component).size(): continue
				mode = TalkLine.SpeakerMode.SPEAKER
				speaker = speaker_choices(component)[at]
			operations.append({"object": target, "property": &"speaker_mode", "value": mode})
			operations.append({"object": target, "property": &"speaker", "value": speaker})
			operations.append({"object": target, "property": &"speaker_id", "value": &""})
		elif id == BULK_BOX_INHERIT or id >= BULK_BOX_FIRST:
			var box: TalkBoxTemplate
			if id >= BULK_BOX_FIRST:
				var at := id - BULK_BOX_FIRST
				if at >= box_choices(component).size(): continue
				box = box_choices(component)[at]
			operations.append({"object": target, "property": &"dialogue_box", "value": box})
		elif id in [BULK_PLACEMENT_INHERIT, BULK_PLACEMENT_SCREEN, BULK_PLACEMENT_FOLLOW]:
			var placement: TalkAnchor
			if id != BULK_PLACEMENT_INHERIT:
				placement = TalkAnchor.new()
				placement.mode = TalkAnchor.Mode.SCREEN if id == BULK_PLACEMENT_SCREEN else TalkAnchor.Mode.NODE_FOLLOW
			operations.append({"object": target, "property": &"placement", "value": placement})
	_commit("Edit selected dialogue lines", operations, RefreshMode.LINES)


func _line_style(selected: bool) -> StyleBoxFlat:
	var accent := Color(0.34, 0.61, 0.96)
	if Engine.is_editor_hint():
		var editor_theme := EditorInterface.get_editor_theme()
		if editor_theme != null and editor_theme.has_color("accent_color", "Editor"):
			accent = editor_theme.get_color("accent_color", "Editor")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.13) if selected else Color(0, 0, 0, 0)
	style.border_color = Color(accent, 0.75) if selected else Color(0, 0, 0, 0)
	style.border_width_left = 2 if selected else 0
	style.content_margin_left = 4.0
	style.content_margin_top = 3.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 3.0
	return style


static func speaker_initial(identity: String) -> String:
	var trimmed := identity.strip_edges()
	if trimmed.is_empty() or trimmed == "—":
		return "—"
	return trimmed.left(1).to_upper()


## Short summary of what a line overrides, e.g. "2 overrides · Event".
static func line_summary(line: TalkLine) -> String:
	if line == null:
		return ""
	var count := 0
	if line.speaker_mode != TalkLine.SpeakerMode.INHERIT: count += 1
	if line.dialogue_box != null: count += 1
	if line.placement != null: count += 1
	if not line.display_name_override.is_empty(): count += 1
	if not line.visual_variant.is_empty(): count += 1
	if line.characters_per_second > 0.0: count += 1
	if line.voice_clip != null: count += 1
	if not line.event_id.is_empty() or line.event_payload != null or line.event_blocking: count += 1
	if not line.line_id.is_empty(): count += 1
	if count == 0:
		return "Defaults"
	var text := "%d override%s" % [count, "" if count == 1 else "s"]
	if not line.event_id.is_empty():
		text += " · Event"
	return text


func _fill_speaker_popup(menu: PopupMenu, conversation: TalkConversation, line: TalkLine) -> void:
	menu.clear()
	menu.add_item("Default (%s)" % inherited_speaker(component, conversation), SPEAKER_INHERIT)
	menu.add_item("None · narrator", SPEAKER_NONE)
	var choices := speaker_choices(component)
	if not choices.is_empty():
		menu.add_separator()
	for index in choices.size():
		menu.add_item(speaker_display(choices[index]), SPEAKER_FIRST + index)
	var checked := SPEAKER_INHERIT
	if line.speaker_mode == TalkLine.SpeakerMode.NONE:
		checked = SPEAKER_NONE
	elif line.speaker_mode == TalkLine.SpeakerMode.SPEAKER:
		var at := choices.find(_speaker_on(line, component))
		checked = SPEAKER_FIRST + at if at >= 0 else SPEAKER_INHERIT
	for index in menu.item_count:
		menu.set_item_checked(index, menu.get_item_id(index) == checked)


func _choose_speaker(id: int, line: TalkLine) -> void:
	if line == null:
		return
	var mode := TalkLine.SpeakerMode.INHERIT
	var value: TalkSpeaker
	match id:
		SPEAKER_INHERIT:
			mode = TalkLine.SpeakerMode.INHERIT
		SPEAKER_NONE:
			mode = TalkLine.SpeakerMode.NONE
		_:
			var choices := speaker_choices(component)
			var at := id - SPEAKER_FIRST
			if at < 0 or at >= choices.size():
				return
			mode = TalkLine.SpeakerMode.SPEAKER
			value = choices[at]
	_commit("Change line speaker", [
		{"object": line, "property": &"speaker_mode", "value": mode},
		{"object": line, "property": &"speaker", "value": value},
		{"object": line, "property": &"speaker_id", "value": &""},
	], RefreshMode.LINES)


## Keeps a dropdown inside its given width. `clip_text` alone is not enough: an
## OptionButton also sizes itself to its longest popup entry.
func _fits_its_box(button: OptionButton) -> void:
	button.clip_text = true
	button.fit_to_longest_item = false


func _on_line_menu(id: int, index: int) -> void:
	match id:
		LINE_INSPECT:
			_select_line(index)
		LINE_UP:
			_move_line(index, -1)
		LINE_DOWN:
			_move_line(index, 1)
		LINE_DUPLICATE:
			_duplicate_line(index)
		LINE_DELETE:
			_confirm_delete_line(index)


func _on_conversation_menu(id: int) -> void:
	match id:
		MENU_RENAME:
			_rename_conversation(_selected_row())
		MENU_DUPLICATE:
			_duplicate_conversation()
		MENU_PROMOTE:
			_promote_conversation()
		MENU_DELETE:
			_confirm_delete_conversation()


func _set_hint(message: String) -> void:
	_empty_hint.text = message


## Points the transport at the selected conversation without interrupting a
## running preview.
func _refresh_preview() -> void:
	_transport.set_source(component, _current_conversation())
	_refresh_preview_status()


func _refresh_preview_status() -> void:
	if _preview_status != null:
		_preview_status.text = _transport.describe()
	if _play_button != null:
		_play_button.text = "■ Stop" if _transport.playing else "▶ Play"


func _on_preview_changed() -> void:
	_refresh_preview_status()
	var conversation := _current_conversation()
	var index := _transport.index
	if conversation == null or index < 0 or index >= conversation.lines.size():
		return
	# Keep the selected row in step with the transport cursor.
	if index != _editing_row:
		_editing_row = index
		_update_line_selection_styles()
		line_selected.emit(conversation, conversation.lines[index], index)
	preview_line.emit(conversation, conversation.lines[index], index, _transport.playing)

#endregion


#region Conversation actions

func _add_conversation() -> void:
	if component == null:
		return
	var conversation := TalkConversation.new()
	conversation.conversation_id = _unique_name()
	# A new conversation gets a first line and a dialogue box, so it validates and
	# previews immediately.
	var boxes := component.dialogue_boxes.duplicate()
	if boxes.is_empty():
		var classic := NPCTalkKit.default_template().duplicate(true) as TalkBoxTemplate
		classic.resource_name = "Classic Panel"
		boxes.append(classic)
	conversation.default_dialogue_box = boxes[0]
	var line := TalkLine.new()
	conversation.lines = [line]
	var conversations := component.conversations.duplicate()
	conversations.append(conversation)
	_commit("Create conversation", [
		{"object": component, "property": &"dialogue_boxes", "value": boxes},
		{"object": component, "property": &"conversations", "value": conversations},
	], RefreshMode.FULL)
	_conversations.select(_conversations.item_count - 1)
	_refresh_lines()
	# Focus the name field; Enter commits it and moves into the first line.
	_lines_title.grab_focus()
	_lines_title.select_all()


func _duplicate_conversation() -> void:
	var source := _current_conversation()
	if source == null:
		return
	var copy := source.duplicate(true) as TalkConversation
	copy.conversation_id = _unique_name(String(source.conversation_id) + "_copy")
	var conversations := component.conversations.duplicate()
	conversations.append(copy)
	_commit("Duplicate conversation", [{
		"object": component, "property": &"conversations", "value": conversations,
	}], RefreshMode.FULL)


func _delete_selected_lines(conversation: TalkConversation) -> void:
	var remaining: Array[TalkLine] = []
	for source in conversation.lines:
		if not _bulk_selected.has(source):
			remaining.append(source)
	_commit("Delete selected dialogue lines", [{
		"object": conversation, "property": &"lines", "value": remaining,
	}], RefreshMode.LINES)
	_bulk_selected.clear()


func _confirm_delete_conversation() -> void:
	var conversation := _current_conversation()
	if conversation == null:
		return
	var count := conversation.lines.size()
	var text := "\"%s\" and its %d line%s are removed from %s." % [
		conversation.conversation_id, count, "" if count == 1 else "s", component.name]
	if _is_library_file(conversation):
		text += " Its library file stays on disk, and other nodes using it keep it."
	text += " Any play(&\"%s\") call in game code stops finding it." % conversation.conversation_id
	_confirm("Delete conversation?", text, "Delete", _delete_conversation)


## Deletes a line, asking first unless it has no text and no overrides.
func _confirm_delete_line(index: int) -> void:
	var conversation := _current_conversation()
	if conversation == null or index < 0 or index >= conversation.lines.size():
		return
	var line := conversation.lines[index]
	if line == null or (line.text.strip_edges().is_empty() and line_summary(line) == "Defaults"):
		_delete_line(index)
		return
	var text := "Line %d and everything on it are removed." % (index + 1)
	if not line.event_id.is_empty():
		text += " That includes its event \"%s\", which game code may rely on." % line.event_id
	_confirm("Delete line %d?" % (index + 1), text, "Delete", _delete_line.bind(index))


## Asks for confirmation before running [param action]. Outside the editor it
## runs at once.
func _confirm(title: String, text: String, ok_text: String, action: Callable) -> void:
	if not Engine.is_editor_hint():
		action.call()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text + "\n\nUndo (%s) brings it back." % ("⌘Z" if OS.get_name() == "macOS" else "Ctrl+Z")
	dialog.ok_button_text = ok_text
	dialog.confirmed.connect(func() -> void:
		action.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 140))


func _delete_conversation() -> void:
	var index := _selected_index()
	if index < 0:
		return
	var conversations := component.conversations.duplicate()
	conversations.remove_at(index)
	_commit("Delete conversation", [{
		"object": component, "property": &"conversations", "value": conversations,
	}], RefreshMode.FULL)


func _rename_conversation(index: int) -> void:
	var conversation := _current_conversation()
	if conversation == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Rename conversation"
	var field := LineEdit.new()
	field.text = String(conversation.conversation_id)
	field.custom_minimum_size.x = 260
	dialog.add_child(field)
	dialog.confirmed.connect(func() -> void:
		rename_to(conversation, field.text, index)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
	field.grab_focus()
	field.select_all()


## Saves the selected conversation next to the library file and registers it
## in the library.
func _promote_conversation() -> void:
	var conversation := _current_conversation()
	if conversation == null:
		_set_hint("Pick a conversation first.")
		return
	if _is_library_file(conversation):
		_set_hint("Already a library file: %s" % conversation.resource_path)
		return
	if component.library == null:
		_set_hint("Assign a Library on the node first — that is where it is registered.")
		return
	var directory := component.library.resource_path.get_base_dir()
	if directory.is_empty():
		_set_hint("Save the Library to a file before saving into it.")
		return

	var path := "%s/%s.tres" % [directory, conversation.conversation_id]
	var error := ResourceSaver.save(conversation, path)
	if error != OK:
		_set_hint("Save failed (%d): %s" % [error, path])
		return

	# Point the node at the saved file and register it, so further edits go to
	# the shared copy.
	var saved: TalkConversation = load(path)
	for index in component.conversations.size():
		if component.conversations[index] == conversation:
			component.conversations[index] = saved
	if not component.library.conversations.has(saved):
		component.library.conversations.append(saved)
	ResourceSaver.save(component.library, component.library.resource_path)
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()
	refresh()
	_set_hint("Saved to %s" % path)


## Validates the whole edited scene.
func _validate_scene() -> void:
	if not Engine.is_editor_hint():
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_set_hint("No scene is open.")
		return
	var library: TalkKitDatabase = component.library if component != null else null
	var report := TalkKitSceneCollector.validate(root, library)
	if report.is_valid():
		var warnings := report.warning_count()
		_set_hint("Scene is valid." if warnings == 0 else "Scene is valid, %d warning(s)." % warnings)
		return
	_set_hint("%d error(s) — see Output." % report.error_count())
	print(JSON.stringify(report.to_dictionary(), "  "))


## Renames [param conversation]. Returns an error message, or "" on success.
## An id already used on this node is refused: find_conversation() returns the
## first match, so the second could never play.
func rename_to(conversation: TalkConversation, wanted_text: String, row := -1) -> String:
	var wanted := wanted_text.strip_edges()
	if wanted.is_empty():
		return "A conversation needs a name."
	if StringName(wanted) == conversation.conversation_id:
		return ""
	for other in component.conversations:
		if other != null and other != conversation and String(other.conversation_id) == wanted:
			var message := "This NPC already has a conversation called \"%s\"." % wanted
			_set_hint(message)
			return message

	_commit("Rename conversation", [{
		"object": conversation,
		"property": &"conversation_id",
		"value": StringName(wanted),
	}], RefreshMode.FULL)
	if row >= 0 and row < _conversations.item_count:
		_conversations.select(row)
		_refresh_lines()
	return ""


## Returns a conversation id that is free on this node.
func _unique_name(base := "conversation") -> StringName:
	var taken: Dictionary = {}
	for conversation in component.conversations:
		if conversation != null:
			taken[String(conversation.conversation_id)] = true
	if not taken.has(base):
		return StringName(base)
	var suffix := 2
	while taken.has("%s_%d" % [base, suffix]):
		suffix += 1
	return StringName("%s_%d" % [base, suffix])

#endregion


#region Line actions

func _add_line() -> void:
	var conversation := _current_conversation()
	if conversation == null:
		return
	var lines := conversation.lines.duplicate()
	lines.append(TalkLine.new())
	_commit("Add dialogue line", [{
		"object": conversation, "property": &"lines", "value": lines,
	}], RefreshMode.LINES)
	_focus_row(lines.size() - 1)


## Enter on the last line appends another; elsewhere it moves down one.
func _on_submit(index: int) -> void:
	var conversation := _current_conversation()
	if conversation == null:
		return
	if index >= conversation.lines.size() - 1:
		_add_line()
	else:
		_focus_row(index + 1)


func _set_text(line: TalkLine, value: String) -> void:
	if line == null or line.text == value:
		return
	_commit("Edit dialogue text", [{
		"object": line, "property": &"text", "value": value,
	}], RefreshMode.NONE, UndoRedo.MERGE_ENDS)


func _on_text_input(
	event: InputEvent,
	index: int,
	edit: TextEdit,
	speaker_menu: MenuButton,
	action_menu: MenuButton,
) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var command := key.ctrl_pressed or key.meta_pressed
	if key.keycode == KEY_ENTER and not key.shift_pressed:
		edit.accept_event()
		_on_submit(index)
	elif command and key.keycode == KEY_D:
		edit.accept_event()
		_duplicate_line(index)
	elif command and key.keycode == KEY_F:
		edit.accept_event()
		_search.grab_focus()
		_search.select_all()
	# Delete, @ and / act as commands only on an empty line; otherwise they are
	# typed.
	elif key.keycode == KEY_DELETE and not command and edit.text.is_empty():
		edit.accept_event()
		_delete_line(index)
	elif key.alt_pressed and key.keycode == KEY_UP:
		edit.accept_event()
		_move_line(index, -1)
	elif key.alt_pressed and key.keycode == KEY_DOWN:
		edit.accept_event()
		_move_line(index, 1)
	elif key.keycode == KEY_AT and edit.text.is_empty():
		edit.accept_event()
		speaker_menu.show_popup()
	elif key.keycode == KEY_SLASH and edit.text.is_empty():
		edit.accept_event()
		action_menu.show_popup()
	elif key.keycode == KEY_ESCAPE:
		edit.accept_event()
		edit.release_focus()


func _move_line(index: int, offset: int) -> void:
	var conversation := _current_conversation()
	var destination := index + offset
	if conversation == null or destination < 0 or destination >= conversation.lines.size():
		return
	var lines: Array[TalkLine] = conversation.lines.duplicate()
	var line: TalkLine = lines[index]
	lines.remove_at(index)
	lines.insert(destination, line)
	_commit("Move dialogue line", [{
		"object": conversation, "property": &"lines", "value": lines,
	}], RefreshMode.LINES)
	_focus_row(destination)


func _move_line_to(index: int, destination: int) -> void:
	var conversation := _current_conversation()
	if conversation == null or index < 0 or destination < 0 \
			or index >= conversation.lines.size() or destination >= conversation.lines.size() \
			or index == destination:
		return
	var lines: Array[TalkLine] = conversation.lines.duplicate()
	var moved: TalkLine = lines[index]
	lines.remove_at(index)
	lines.insert(destination, moved)
	_commit("Reorder dialogue line", [{
		"object": conversation, "property": &"lines", "value": lines,
	}], RefreshMode.LINES)
	_focus_row(destination)


func _duplicate_line(index: int) -> void:
	var conversation := _current_conversation()
	if conversation == null or index < 0 or index >= conversation.lines.size():
		return
	var copy := conversation.lines[index].duplicate(true) as TalkLine
	copy.line_id = &""
	var lines := conversation.lines.duplicate()
	lines.insert(index + 1, copy)
	_commit("Duplicate dialogue line", [{
		"object": conversation, "property": &"lines", "value": lines,
	}], RefreshMode.LINES)
	_focus_row(index + 1)


func _delete_line(index: int) -> void:
	var conversation := _current_conversation()
	if conversation == null or index >= conversation.lines.size():
		return
	var lines := conversation.lines.duplicate()
	lines.remove_at(index)
	_commit("Delete dialogue line", [{
		"object": conversation, "property": &"lines", "value": lines,
	}], RefreshMode.LINES)


func _select_line(index: int) -> void:
	var conversation := _current_conversation()
	if conversation == null or index < 0 or index >= conversation.lines.size():
		line_selected.emit(conversation, null, -1)
		return
	_editing_row = index
	_update_line_selection_styles()
	# Picking another line by hand stops playback.
	if _transport.playing and index != _transport.index:
		_transport.stop()
	_transport.go_to(index)
	# go_to() emits no signal, so refresh the transport label here.
	_refresh_preview_status()
	line_selected.emit(conversation, conversation.lines[index], index)


func _update_line_selection_styles() -> void:
	for child in _lines_box.get_children():
		var index := int(child.get_meta("talkkit_line_index", -1))
		if index >= 0 and child is PanelContainer:
			(child as PanelContainer).add_theme_stylebox_override(
				"panel", _line_style(index == _editing_row))


func refresh_selected_line() -> void:
	var wanted := _editing_row
	_refresh_lines()
	if wanted >= 0:
		_select_line(wanted)


func select_context(conversation: TalkConversation, line_index: int) -> void:
	if component == null or conversation == null:
		return
	var source_index := component.conversations.find(conversation)
	if source_index < 0:
		return
	# A deep link must still work when the destination was hidden by a search.
	if not _search.text.is_empty():
		_search.text = ""
		refresh()
	for row in _conversations.item_count:
		if int(_conversations.get_item_metadata(row)) == source_index:
			_conversations.select(row)
			_editing_row = clampi(line_index, 0, maxi(0, conversation.lines.size() - 1))
			_refresh_lines()
			return


func focus_line_text(index: int) -> void:
	for child in _lines_box.get_children():
		if int(child.get_meta("talkkit_line_index", -1)) != index:
			continue
		var edit := _find_text_edit(child)
		if edit != null:
			edit.grab_focus()
			edit.set_caret_line(edit.get_line_count() - 1)
			edit.set_caret_column(edit.get_line(edit.get_line_count() - 1).length())
		return


func _focus_row(index: int) -> void:
	_editing_row = index
	_refresh_preview()
	await get_tree().process_frame
	for child in _lines_box.get_children():
		if int(child.get_meta("talkkit_line_index", -1)) != index:
			continue
		var edit := _find_text_edit(child)
		if edit != null:
			edit.grab_focus()
		_select_line(index)
		return


func _find_text_edit(node: Node) -> TextEdit:
	if node is TextEdit:
		return node
	for child in node.get_children():
		var found := _find_text_edit(child)
		if found != null:
			return found
	return null

#endregion


#region Helpers

## The highlighted row in the list, which is not the same as the index into
## `conversations` whenever the array has an empty element.
func _selected_row() -> int:
	var selected := _conversations.get_selected_items()
	return -1 if selected.is_empty() else selected[0]


## The index into `conversations`, not the row number.
func _selected_index() -> int:
	var selected := _conversations.get_selected_items()
	if selected.is_empty():
		return -1
	var mapped: Variant = _conversations.get_item_metadata(selected[0])
	return int(mapped) if mapped != null else -1


func _current_conversation() -> TalkConversation:
	var index := _selected_index()
	if component == null or index < 0 or index >= component.conversations.size():
		return null
	return component.conversations[index]


## What a speaker is called, for any list that has to name one.
static func speaker_display(speaker: TalkSpeaker) -> String:
	return CollectionSummary.entry_name(speaker, CollectionSummary.Kind.SPEAKERS)


## The speaker a line names itself, if any. Must match the line half of
## NPCTalkKit.resolve_speaker().
static func _speaker_on(line: TalkLine, node: NPCTalkKit = null) -> TalkSpeaker:
	if line == null or line.speaker_mode != TalkLine.SpeakerMode.SPEAKER:
		return null
	if line.speaker != null:
		return line.speaker
	return node.find_speaker(line.speaker_id) if node != null else null


## Who the panel shows against a line — exactly what the player will read.
static func speaker_label(
	node: NPCTalkKit, conversation: TalkConversation, line: TalkLine,
) -> String:
	if line == null:
		return ""
	if not line.display_name_override.is_empty():
		return line.display_name_override
	match line.speaker_mode:
		TalkLine.SpeakerMode.NONE:
			return "—"
		TalkLine.SpeakerMode.SPEAKER:
			var named := _speaker_on(line, node)
			return "—" if named == null else speaker_display(named)
	return inherited_speaker(node, conversation)


## What a line without a speaker override resolves to; shown in the Default
## entry.
static func inherited_speaker(_node: NPCTalkKit, conversation: TalkConversation) -> String:
	var speaker: TalkSpeaker = conversation.default_speaker if conversation != null else null
	return "—" if speaker == null else speaker_display(speaker)


## The node's own speaker collection.
static func speaker_choices(node: NPCTalkKit) -> Array[TalkSpeaker]:
	var found: Array[TalkSpeaker] = []
	if node == null:
		return found
	for speaker in node.speakers:
		if speaker != null and not found.has(speaker):
			found.append(speaker)
	return found


static func box_choices(node: NPCTalkKit) -> Array[TalkBoxTemplate]:
	var found: Array[TalkBoxTemplate] = []
	if node == null:
		return found
	for box in node.dialogue_boxes:
		if box != null and not found.has(box):
			found.append(box)
	return found


static func label_key(conversation: TalkConversation) -> String:
	return String(conversation.conversation_id)


## A conversation saved to its own file, as opposed to one embedded in the scene.
func _is_library_file(conversation: TalkConversation) -> bool:
	var path := conversation.resource_path
	return not path.is_empty() and not path.contains("::")


## Applies property changes through the editor's undo history, or directly
## outside the editor.
func _commit(
	action: String,
	operations: Array[Dictionary],
	refresh_mode: RefreshMode,
	merge_mode := UndoRedo.MERGE_DISABLE,
) -> void:
	if operations.is_empty():
		return
	if Engine.is_editor_hint() and editor_plugin != null:
		var undo := editor_plugin.get_undo_redo()
		var context: Object = operations[0]["object"]
		undo.create_action(action, merge_mode, context)
		for operation in operations:
			var object: Object = operation["object"]
			var property: StringName = operation["property"]
			undo.add_do_property(object, property, operation["value"])
			undo.add_undo_property(object, property, object.get(property))
		undo.add_do_method(self, &"_after_mutation", refresh_mode)
		undo.add_undo_method(self, &"_after_mutation", refresh_mode)
		undo.commit_action()
		return
	for operation in operations:
		(operation["object"] as Object).set(operation["property"], operation["value"])
	_after_mutation(refresh_mode)


func _after_mutation(refresh_mode: RefreshMode) -> void:
	changed.emit()
	match refresh_mode:
		RefreshMode.LINES:
			_refresh_lines()
		RefreshMode.FULL:
			refresh()


## Refreshes after actions that write files or have editor-only side effects.
func _dirty() -> void:
	_after_mutation(RefreshMode.NONE)

#endregion
