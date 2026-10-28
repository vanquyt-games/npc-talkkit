@tool
extends VBoxContainer

## Main-screen authoring workspace. One instance follows whichever NPCTalkKit
## node is the current context; nodes do not get separate editor pages.

const ConversationEditor := preload("res://addons/npc_talkkit/editor/talkkit_panel.gd")
const LineDetail := preload("res://addons/npc_talkkit/editor/talkkit_line_detail.gd")
const ResourceManager := preload("res://addons/npc_talkkit/editor/talkkit_resource_manager.gd")

enum Section { CONVERSATIONS, SPEAKERS, BOXES }

var plugin: EditorPlugin
var component: NPCTalkKit
var follow_scene_selection := true

var _node_picker: OptionButton
var _follow: CheckButton
var _status: Label
var _footer_status: Label
var _footer_hints: Array[Control] = []
var _version_label: Label
var _save: Button
var _tabs: TabContainer
var _empty: CenterContainer
var _empty_select: Button
var _conversation_editor: Control
var _line_detail: Control
var _conversation_split: HSplitContainer
var _detail_panel: PanelContainer
var _detail_button: Button
var _detail_popup: PopupPanel
var _drawer_detail: Control
var _speaker_manager: Control
var _box_manager: Control
var _script_placeholder: Control
var _updating_context := false
var _dirty := false
var _shared_dirty := false
var _back: Button
var _history: Array[Dictionary] = []
var _node_states: Dictionary = {}
var _validation_drawer: PanelContainer
var _validation_list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	refresh_contexts()
	refresh()


func _build() -> void:
	var context_margin := MarginContainer.new()
	context_margin.add_theme_constant_override("margin_left", 8)
	context_margin.add_theme_constant_override("margin_top", 6)
	context_margin.add_theme_constant_override("margin_right", 8)
	context_margin.add_theme_constant_override("margin_bottom", 6)
	add_child(context_margin)
	var context := HBoxContainer.new()
	context.add_theme_constant_override("separation", 8)
	context_margin.add_child(context)

	var title := Label.new()
	title.text = "NPC TalkKit"
	title.add_theme_font_size_override("font_size", 16)
	context.add_child(title)

	_node_picker = OptionButton.new()
	_node_picker.custom_minimum_size.x = 220
	_node_picker.clip_text = true
	_node_picker.fit_to_longest_item = false
	_node_picker.item_selected.connect(_on_node_picked)
	context.add_child(_node_picker)

	_follow = CheckButton.new()
	_follow.text = "Follow scene selection"
	_follow.button_pressed = true
	_follow.toggled.connect(func(value: bool) -> void:
		follow_scene_selection = value)
	context.add_child(_follow)

	_detail_button = Button.new()
	_detail_button.text = "Details"
	_detail_button.tooltip_text = "Open selected line details"
	_detail_button.visible = false
	_detail_button.pressed.connect(_open_detail_drawer)
	context.add_child(_detail_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.add_child(spacer)

	_back = Button.new()
	_back.text = "← Back"
	_back.tooltip_text = "Return to the originating conversation line"
	_back.visible = false
	_back.pressed.connect(_go_back)
	context.add_child(_back)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	context.add_child(_status)

	var validate := Button.new()
	validate.text = "Validate"
	validate.pressed.connect(_validate)
	context.add_child(validate)

	_save = Button.new()
	_save.text = "Save"
	_save.disabled = true
	_save.pressed.connect(save_all)
	context.add_child(_save)

	var rule := HSeparator.new()
	add_child(rule)

	_empty = CenterContainer.new()
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var empty_column := VBoxContainer.new()
	empty_column.custom_minimum_size.x = 360
	empty_column.add_theme_constant_override("separation", 8)
	_empty.add_child(empty_column)
	var empty_title := Label.new()
	empty_title.text = "Select an NPCTalkKit node"
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_title.add_theme_font_size_override("font_size", 20)
	empty_column.add_child(empty_title)
	var empty_copy := Label.new()
	empty_copy.text = "Choose a TalkKit node in the Scene Tree. This workspace will keep that node as its editing context."
	empty_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_copy.modulate.a = 0.72
	empty_column.add_child(empty_copy)
	_empty_select = Button.new()
	_empty_select.text = "Select in Scene Tree"
	_empty_select.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_select.pressed.connect(_select_first_talkkit)
	empty_column.add_child(_empty_select)
	var empty_note := Label.new()
	empty_note.text = "Selecting an unrelated node later will not discard your TalkKit context."
	empty_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_note.add_theme_font_size_override("font_size", 11)
	empty_note.modulate.a = 0.62
	empty_column.add_child(empty_note)
	add_child(_empty)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tabs_visible = true
	_tabs.tab_changed.connect(_on_tab_changed)
	add_child(_tabs)

	var conversations := HSplitContainer.new()
	_conversation_split = conversations
	conversations.name = "Conversations"
	conversations.split_offset = _saved_split("line_detail", -380)
	conversations.dragged.connect(_save_split.bind("line_detail"))
	_tabs.add_child(conversations)
	_conversation_editor = ConversationEditor.new()
	_conversation_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conversation_editor.line_selected.connect(_on_line_selected)
	_conversation_editor.preview_line.connect(_on_preview_line)
	_conversation_editor.changed.connect(_on_conversation_content_changed)
	_conversation_editor.navigate_manager.connect(_on_navigate_resource)
	conversations.add_child(_conversation_editor)
	var detail_panel := PanelContainer.new()
	_detail_panel = detail_panel
	detail_panel.custom_minimum_size.x = 360
	conversations.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		detail_margin.add_theme_constant_override("margin_" + side, 8)
	detail_panel.add_child(detail_margin)
	_line_detail = LineDetail.new()
	_line_detail.editor_plugin = plugin
	_line_detail.changed.connect(_on_line_detail_changed)
	_line_detail.navigate_resource.connect(_on_navigate_resource)
	detail_margin.add_child(_line_detail)

	_detail_popup = PopupPanel.new()
	_detail_popup.title = "Line details"
	add_child(_detail_popup)
	var drawer_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		drawer_margin.add_theme_constant_override("margin_" + side, 10)
	_detail_popup.add_child(drawer_margin)
	_drawer_detail = LineDetail.new()
	_drawer_detail.custom_minimum_size.x = 340
	_drawer_detail.editor_plugin = plugin
	_drawer_detail.changed.connect(_on_drawer_detail_changed)
	_drawer_detail.navigate_resource.connect(_on_navigate_resource)
	drawer_margin.add_child(_drawer_detail)

	_speaker_manager = ResourceManager.new()
	_speaker_manager.name = "Speakers"
	_speaker_manager.kind = ResourceManager.Kind.SPEAKERS
	_speaker_manager.editor_plugin = plugin
	_speaker_manager.changed.connect(_on_resource_manager_changed.bind(_speaker_manager))
	_tabs.add_child(_speaker_manager)

	_box_manager = ResourceManager.new()
	_box_manager.name = "Dialogue Boxes"
	_box_manager.kind = ResourceManager.Kind.BOXES
	_box_manager.editor_plugin = plugin
	_box_manager.changed.connect(_on_resource_manager_changed.bind(_box_manager))
	_tabs.add_child(_box_manager)

	_script_placeholder = _build_script_placeholder()
	_script_placeholder.name = "Script · Coming soon"
	_tabs.add_child(_script_placeholder)

	_validation_drawer = PanelContainer.new()
	_validation_drawer.visible = false
	_validation_drawer.custom_minimum_size.y = 150
	add_child(_validation_drawer)
	var validation_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		validation_margin.add_theme_constant_override("margin_" + side, 8)
	_validation_drawer.add_child(validation_margin)
	var validation_stack := VBoxContainer.new()
	validation_margin.add_child(validation_stack)
	var validation_header := HBoxContainer.new()
	validation_stack.add_child(validation_header)
	var validation_title := Label.new()
	validation_title.text = "Validation issues"
	validation_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	validation_title.add_theme_font_size_override("font_size", 13)
	validation_header.add_child(validation_title)
	var close_validation := Button.new()
	close_validation.text = "Close"
	close_validation.pressed.connect(func() -> void: _validation_drawer.visible = false)
	validation_header.add_child(close_validation)
	var validation_scroll := ScrollContainer.new()
	validation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	validation_stack.add_child(validation_scroll)
	_validation_list = VBoxContainer.new()
	_validation_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	validation_scroll.add_child(_validation_list)

	var footer_rule := HSeparator.new()
	add_child(footer_rule)
	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 8)
	footer_margin.add_theme_constant_override("margin_top", 4)
	footer_margin.add_theme_constant_override("margin_right", 8)
	footer_margin.add_theme_constant_override("margin_bottom", 4)
	add_child(footer_margin)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer_margin.add_child(footer)
	_footer_status = Label.new()
	_footer_status.add_theme_font_size_override("font_size", 11)
	footer.add_child(_footer_status)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	var undo_key := "⌘Z" if OS.get_name() == "macOS" else "Ctrl+Z"
	for hint in ["Enter: next line", "Shift+Enter: newline", "%s: undo" % undo_key]:
		var label := Label.new()
		label.text = hint
		label.add_theme_font_size_override("font_size", 11)
		label.modulate.a = 0.65
		footer.add_child(label)
		_footer_hints.append(label)
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	footer.add_child(gap)
	_footer_hints.append(gap)
	_version_label = Label.new()
	_version_label.text = "NPC TalkKit v%s" % TalkKitConstants.ADDON_VERSION
	_version_label.add_theme_font_size_override("font_size", 11)
	_version_label.modulate.a = 0.65
	footer.add_child(_version_label)
	footer.add_child(_footer_link("Product ↗", TalkKitConstants.PRODUCT_URL))
	footer.add_child(_footer_link("Docs ↗", TalkKitConstants.DOCS_URL))
	footer.add_child(_footer_link("Support ↗", TalkKitConstants.SUPPORT_URL))
	# Labels and LinkButtons align differently in an HBox; centre all of them
	# so the text shares one line.
	for child in footer.get_children():
		(child as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resized.connect(_update_responsive)


func _footer_link(text: String, url: String) -> LinkButton:
	var link := LinkButton.new()
	link.text = text
	link.uri = url
	link.tooltip_text = url
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.add_theme_font_size_override("font_size", 11)
	return link


func _build_script_placeholder() -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 330)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var eyebrow := Label.new()
	eyebrow.text = "COMING SOON  ·  POWER WORKFLOW"
	eyebrow.modulate = Color(0.45, 0.7, 1.0)
	eyebrow.add_theme_font_size_override("font_size", 11)
	column.add_child(eyebrow)
	var title := Label.new()
	title.text = "Write dialogue like a script"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var description := Label.new()
	description.text = (
		"A fast text view for long conversations, clean Git diffs, and writer-friendly review. "
		+ "It will remain a view over the same TalkConversation and TalkLine resources—never a second data model."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate.a = 0.78
	column.add_child(description)
	var sample_panel := PanelContainer.new()
	column.add_child(sample_panel)
	var sample := Label.new()
	sample.text = (
		"conversation forest_checkpoint\n\n"
		+ "@Haru\nHello {{player_name}}. The lower trail is calm.\n\n"
		+ "@Ren [box=SpeechBubble] [event=canopy_offer]\n"
		+ "From the canopy: He says that to everyone."
	)
	sample.add_theme_font_size_override("font_size", 12)
	var sample_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		sample_margin.add_theme_constant_override("margin_" + side, 12)
	sample_margin.add_child(sample)
	sample_panel.add_child(sample_margin)
	var note := Label.new()
	note.text = "Preview only · syntax, parser, and two-way sync are planned for a future update."
	note.modulate.a = 0.6
	note.add_theme_font_size_override("font_size", 11)
	column.add_child(note)
	return center
	call_deferred("_update_responsive")


func _saved_split(key: String, fallback: int) -> int:
	if not Engine.is_editor_hint():
		return fallback
	var settings := EditorInterface.get_editor_settings()
	var path := "npc_talkkit/layout/%s" % key
	return int(settings.get_setting(path)) if settings.has_setting(path) else fallback


func _save_split(offset: int, key: String) -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_setting("npc_talkkit/layout/%s" % key, offset)


func set_component(value: NPCTalkKit) -> void:
	if component == value:
		refresh_contexts()
		return
	_store_node_state()
	component = value
	_dirty = false
	_shared_dirty = false
	# Shows the node summary until the conversation editor selects a line.
	if _line_detail != null:
		_line_detail.editor_plugin = plugin
		_line_detail.set_line(component, null, null, -1)
	if _drawer_detail != null:
		_drawer_detail.editor_plugin = plugin
		_drawer_detail.set_line(component, null, null, -1)
	if _conversation_editor != null:
		_conversation_editor.component = component
		_conversation_editor.editor_plugin = plugin
		_conversation_editor.refresh()
	if _speaker_manager != null:
		_speaker_manager.editor_plugin = plugin
		_speaker_manager.component = component
		_speaker_manager.refresh()
	if _box_manager != null:
		_box_manager.editor_plugin = plugin
		_box_manager.component = component
		_box_manager.refresh()
	_restore_node_state()
	refresh_contexts()
	refresh()


func open_section(section: String, resource: Resource = null) -> void:
	if _tabs == null:
		return
	match section:
		"speakers":
			_tabs.current_tab = Section.SPEAKERS
			if resource != null:
				_speaker_manager.select_resource(resource)
		"boxes":
			_tabs.current_tab = Section.BOXES
			if resource != null:
				_box_manager.select_resource(resource)
		_:
			_tabs.current_tab = Section.CONVERSATIONS
	_update_back()


func _on_navigate_resource(section: String, resource: Resource) -> void:
	_history.append({
		"component": component,
		"conversation": _conversation_editor._current_conversation(),
		"line": _conversation_editor._editing_row,
		"tab": _tabs.current_tab,
	})
	open_section(section, resource)


func _go_back() -> void:
	if _history.is_empty():
		return
	var location: Dictionary = _history.pop_back()
	var target := location.get("component") as NPCTalkKit
	if is_instance_valid(target):
		set_component(target)
	_tabs.current_tab = int(location.get("tab", Section.CONVERSATIONS))
	if _tabs.current_tab == Section.CONVERSATIONS:
		_conversation_editor.select_context(
			location.get("conversation") as TalkConversation,
			int(location.get("line", 0)))
	_update_back()


func _update_back() -> void:
	if _back != null:
		_back.visible = not _history.is_empty()


func _store_node_state() -> void:
	if not is_instance_valid(component) or _tabs == null:
		return
	_node_states[component.get_instance_id()] = {
		"tab": _tabs.current_tab,
		"conversation": _conversation_editor._current_conversation(),
		"line": _conversation_editor._editing_row,
		"speaker": _speaker_manager._selected,
		"box": _box_manager._selected,
	}


func _restore_node_state() -> void:
	if not is_instance_valid(component):
		return
	var state: Dictionary = _node_states.get(component.get_instance_id(), {})
	if state.is_empty():
		return
	_tabs.current_tab = int(state.get("tab", Section.CONVERSATIONS))
	_conversation_editor.select_context(
		state.get("conversation") as TalkConversation,
		int(state.get("line", 0)))
	var speaker := state.get("speaker") as Resource
	if speaker != null:
		_speaker_manager.select_resource(speaker)
	var box := state.get("box") as Resource
	if box != null:
		_box_manager.select_resource(box)


func _on_tab_changed(tab: int) -> void:
	if tab == Section.SPEAKERS and _speaker_manager != null:
		_speaker_manager.component = component
		_speaker_manager.refresh()
	elif tab == Section.BOXES and _box_manager != null:
		_box_manager.component = component
		_box_manager.refresh()
	_update_responsive()


func _update_responsive() -> void:
	if _detail_panel == null or _detail_button == null or _tabs == null:
		return
	# The text and detail panes need about 1,000 px together; below that the
	# detail pane becomes a drawer.
	var narrow := size.x > 0.0 and size.x < 1080.0
	_detail_panel.visible = not narrow
	# Keyboard hints give way first; the version and links always stay.
	for hint in _footer_hints:
		hint.visible = not narrow
	_detail_button.visible = narrow and _tabs.current_tab == Section.CONVERSATIONS and component != null
	if _conversation_editor != null:
		# TabContainer counts the minimum widths of inactive tabs, so the control
		# cannot shrink much below 1,014 px; this threshold sits just above that.
		_conversation_editor.set_narrow_navigation(size.x > 0.0 and size.x < 1024.0)
	if not narrow and _detail_popup != null:
		_detail_popup.hide()


func _open_detail_drawer() -> void:
	if _detail_popup == null or _drawer_detail == null:
		return
	_drawer_detail.set_line(
		component,
		_conversation_editor._current_conversation(),
		_conversation_editor._current_conversation().lines[_conversation_editor._editing_row]
			if _conversation_editor._current_conversation() != null
			and _conversation_editor._editing_row >= 0
			and _conversation_editor._editing_row < _conversation_editor._current_conversation().lines.size()
			else null,
		_conversation_editor._editing_row)
	_detail_popup.popup_centered_clamped(Vector2i(390, maxi(520, int(size.y * 0.8))))


func observe_scene_selection(selected: Array) -> void:
	refresh_contexts()
	if not follow_scene_selection:
		return
	for node in selected:
		if node is NPCTalkKit:
			set_component(node)
			return


func refresh_contexts() -> void:
	if _node_picker == null:
		return
	_updating_context = true
	_node_picker.clear()
	var nodes: Array[NPCTalkKit] = []
	if Engine.is_editor_hint():
		nodes = _talkkits(EditorInterface.get_edited_scene_root())
	for index in nodes.size():
		var node: NPCTalkKit = nodes[index]
		_node_picker.add_item("%s / NPCTalkKit" % node.name)
		_node_picker.set_item_metadata(index, node.get_instance_id())
	# After a scene reload the node may already be freed; a freed object passed
	# to a typed Array.find() logs an error, so it is cleared first.
	if component != null and not is_instance_valid(component):
		component = null
	var at := nodes.find(component) if component != null else -1
	_node_picker.selected = at if at >= 0 else -1
	_node_picker.disabled = nodes.is_empty()
	if _empty_select != null:
		_empty_select.visible = not nodes.is_empty()
	_updating_context = false


static func _talkkits(root: Node) -> Array[NPCTalkKit]:
	var found: Array[NPCTalkKit] = []
	if root == null:
		return found
	if root is NPCTalkKit:
		found.append(root)
	for child in root.get_children():
		found.append_array(_talkkits(child))
	return found


func _on_node_picked(index: int) -> void:
	if _updating_context:
		return
	var id := int(_node_picker.get_item_metadata(index))
	var object := instance_from_id(id)
	if object is NPCTalkKit:
		follow_scene_selection = false
		_follow.button_pressed = false
		set_component(object)


func _select_first_talkkit() -> void:
	if not Engine.is_editor_hint():
		return
	var nodes := _talkkits(EditorInterface.get_edited_scene_root())
	if nodes.is_empty():
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(nodes[0])
	set_component(nodes[0])


func refresh() -> void:
	if _tabs == null:
		return
	var has_component := is_instance_valid(component)
	_empty.visible = not has_component
	_tabs.visible = has_component
	_save.disabled = not _has_unsaved_changes()
	_refresh_status()


func _refresh_status() -> void:
	if _status == null:
		return
	if not is_instance_valid(component):
		_status.text = "No editing context"
		if _footer_status != null:
			_footer_status.text = "No editing context"
		return
	var report := _report()
	var errors := report.error_count()
	var warnings := report.warning_count()
	var validity := "Valid"
	if errors > 0:
		validity = "%d error%s" % [errors, "" if errors == 1 else "s"]
	elif warnings > 0:
		validity = "%d warning%s" % [warnings, "" if warnings == 1 else "s"]
	_status.text = "%s · %s" % [
		validity, "Unsaved" if _has_unsaved_changes() else "Saved",
	]
	if _footer_status != null:
		var lines := 0
		for conversation in component.conversations:
			if conversation != null:
				lines += conversation.lines.size()
		_footer_status.text = "%s · %d line%s" % [
			validity, lines, "" if lines == 1 else "s",
		]


func _report() -> TalkValidationReport:
	var report := TalkValidationReport.new()
	if not is_instance_valid(component):
		return report
	for speaker in component.speakers:
		report.merge(TalkValidator.validate_speaker(speaker, false))
	for conversation in component.conversations:
		report.merge(TalkValidator.validate_conversation(conversation, component.speakers))
		report.merge(TalkValidator.validate_against_collection(
			conversation, component.speakers, component.dialogue_boxes))
	return report


func _validate() -> void:
	_refresh_status()
	var report := _report()
	_rebuild_validation_drawer(report)
	_validation_drawer.visible = true


func _rebuild_validation_drawer(report: TalkValidationReport) -> void:
	for child in _validation_list.get_children():
		child.queue_free()
	if report.issues.is_empty():
		var valid := Label.new()
		valid.text = "✓ No validation issues."
		valid.modulate = Color(0.55, 0.9, 0.62)
		_validation_list.add_child(valid)
		return
	for issue in report.issues:
		var row := HBoxContainer.new()
		_validation_list.add_child(row)
		var button := Button.new()
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s  %s%s" % [
			"●" if issue.severity == &"error" else "▲",
			issue.message,
			"  ·  %s" % issue.field if not issue.field.is_empty() else "",
		]
		button.tooltip_text = "Open the content related to this issue"
		button.pressed.connect(_navigate_issue.bind(issue))
		row.add_child(button)
		var recovery := _recovery_label(issue)
		if not recovery.is_empty():
			var fix := Button.new()
			fix.text = recovery
			fix.pressed.connect(_apply_recovery.bind(issue))
			row.add_child(fix)


func _navigate_issue(issue: TalkValidationIssue) -> void:
	if issue == null or component == null:
		return
	if not issue.speaker_id.is_empty():
		for speaker in component.speakers:
			if speaker != null and speaker.speaker_id == issue.speaker_id:
				open_section("speakers", speaker)
				return
	var conversation: TalkConversation
	for candidate in component.conversations:
		if candidate != null and candidate.conversation_id == issue.conversation_id:
			conversation = candidate
			break
	if conversation == null:
		return
	var line_index := issue.line_index
	if line_index < 0 and not issue.line_id.is_empty():
		for index in conversation.lines.size():
			if conversation.lines[index] != null and conversation.lines[index].line_id == issue.line_id:
				line_index = index
				break
	open_section("conversations")
	_conversation_editor.select_context(conversation, maxi(0, line_index))
	if line_index >= 0:
		if issue.field == "text":
			_conversation_editor.focus_line_text(line_index)
		else:
			_line_detail.focus_field(issue.field)
	_validation_drawer.visible = false


func _recovery_label(issue: TalkValidationIssue) -> String:
	match String(issue.code):
		"SPEAKER_NOT_IN_COLLECTION", "BOX_NOT_IN_COLLECTION": return "Add to this node"
		"MISSING_DIALOGUE_BOX": return "Use Classic Panel"
		"MISSING_SPEAKER_REFERENCE", "UNKNOWN_SPEAKER": return "Make narrator"
	return ""


func _apply_recovery(issue: TalkValidationIssue) -> void:
	var target := _issue_target(issue)
	var conversation := target.get("conversation") as TalkConversation
	var line := target.get("line") as TalkLine
	var operations: Array[Dictionary] = []
	var action := "Resolve TalkKit validation issue"
	match String(issue.code):
		"SPEAKER_NOT_IN_COLLECTION":
			var speaker: TalkSpeaker = line.speaker if line != null else conversation.default_speaker
			if speaker != null and not component.speakers.has(speaker):
				var speakers := component.speakers.duplicate()
				speakers.append(speaker)
				operations.append({"object": component, "property": &"speakers", "value": speakers})
				action = "Add speaker to this node"
		"BOX_NOT_IN_COLLECTION":
			var box: TalkBoxTemplate = line.dialogue_box if line != null else conversation.default_dialogue_box
			if box != null and not component.dialogue_boxes.has(box):
				var boxes := component.dialogue_boxes.duplicate()
				boxes.append(box)
				operations.append({"object": component, "property": &"dialogue_boxes", "value": boxes})
				action = "Add dialogue box to this node"
		"MISSING_DIALOGUE_BOX":
			var available_boxes := component.dialogue_boxes.duplicate()
			if component.dialogue_boxes.is_empty():
				var classic := NPCTalkKit.default_template().duplicate(true) as TalkBoxTemplate
				classic.resource_name = "Classic Panel"
				available_boxes.append(classic)
				operations.append({
					"object": component, "property": &"dialogue_boxes", "value": available_boxes,
				})
			if conversation != null:
				operations.append({
					"object": conversation,
					"property": &"default_dialogue_box",
					"value": available_boxes[0],
				})
			action = "Use Classic Panel"
		"MISSING_SPEAKER_REFERENCE", "UNKNOWN_SPEAKER":
			if line != null:
				operations.append_array([
					{"object": line, "property": &"speaker_mode", "value": TalkLine.SpeakerMode.NONE},
					{"object": line, "property": &"speaker", "value": null},
					{"object": line, "property": &"speaker_id", "value": &""},
				])
				action = "Make line narrator"
	_commit_recovery(action, operations)


func _commit_recovery(action: String, operations: Array[Dictionary]) -> void:
	if operations.is_empty():
		return
	if Engine.is_editor_hint() and plugin != null:
		var undo := plugin.get_undo_redo()
		undo.create_action(action, UndoRedo.MERGE_DISABLE, operations[0]["object"])
		for operation in operations:
			var object: Object = operation["object"]
			var property: StringName = operation["property"]
			undo.add_do_property(object, property, operation["value"])
			undo.add_undo_property(object, property, object.get(property))
		undo.add_do_method(self, &"_after_recovery")
		undo.add_undo_method(self, &"_after_recovery")
		undo.commit_action()
		return
	for operation in operations:
		(operation["object"] as Object).set(operation["property"], operation["value"])
	_after_recovery()


func _after_recovery() -> void:
	_on_content_changed()
	_conversation_editor.refresh()
	_rebuild_validation_drawer(_report())


func _issue_target(issue: TalkValidationIssue) -> Dictionary:
	var result := {"conversation": null, "line": null}
	for conversation in component.conversations:
		if conversation == null or conversation.conversation_id != issue.conversation_id:
			continue
		result["conversation"] = conversation
		if issue.line_index >= 0 and issue.line_index < conversation.lines.size():
			result["line"] = conversation.lines[issue.line_index]
		return result
	return result


func _on_line_selected(conversation: TalkConversation, line: TalkLine, index: int) -> void:
	_line_detail.set_line(component, conversation, line, index)
	_drawer_detail.set_line(component, conversation, line, index)


func _on_preview_line(_conversation: TalkConversation, _line: TalkLine, _index: int, animate: bool) -> void:
	_line_detail.set_preview_animated(animate)
	_drawer_detail.set_preview_animated(animate)


func _on_line_detail_changed() -> void:
	_conversation_editor.refresh_selected_line()
	if _is_shared(_line_detail.conversation):
		_shared_dirty = true
	_on_content_changed()


func _on_drawer_detail_changed() -> void:
	_line_detail.set_line(
		component,
		_conversation_editor._current_conversation(),
		_drawer_detail.line,
		_drawer_detail.line_index)
	_on_line_detail_changed()


func _on_content_changed() -> void:
	_dirty = true
	_refresh_status()


func _on_conversation_content_changed() -> void:
	if _is_shared(_conversation_editor._current_conversation()):
		_shared_dirty = true
	_line_detail.refresh_preview()
	_drawer_detail.refresh_preview()
	_on_content_changed()


func _on_resource_manager_changed(manager: Control) -> void:
	if manager != null and _is_shared(manager.get("_selected") as Resource):
		_shared_dirty = true
	_on_content_changed()


func _has_unsaved_changes() -> bool:
	if not Engine.is_editor_hint():
		return _dirty
	var root := EditorInterface.get_edited_scene_root()
	if root != null and EditorInterface.get_unsaved_scenes().has(root.scene_file_path):
		return true
	return _shared_dirty


static func _is_shared(resource: Resource) -> bool:
	return resource != null and not resource.resource_path.is_empty() \
		and not resource.resource_path.contains("::")


func save_all() -> void:
	if not is_instance_valid(component):
		return
	for resource in component.conversations + component.speakers + component.dialogue_boxes:
		if resource != null and not resource.resource_path.is_empty() and not resource.resource_path.contains("::"):
			ResourceSaver.save(resource, resource.resource_path)
	if Engine.is_editor_hint():
		EditorInterface.save_scene()
	_dirty = false
	_shared_dirty = false
	refresh()
