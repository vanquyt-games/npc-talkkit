@tool
## Inspector card for an NPCTalkKit node: summarizes what the node owns and
## opens the TalkKit workspace, where authoring happens.
extends MarginContainer

const ConversationsSummary := preload("res://addons/npc_talkkit/editor/talkkit_conversations_summary.gd")
const CollectionSummary := preload("res://addons/npc_talkkit/editor/talkkit_collection_summary.gd")

var component: NPCTalkKit
var plugin: EditorPlugin

var _open: Button
var _conversation_button: Button
var _speaker_button: Button
var _box_button: Button
var _library: Label
var _signature := ""


func _ready() -> void:
	add_theme_constant_override("margin_top", 6)
	add_theme_constant_override("margin_bottom", 10)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style())
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var icon := TextureRect.new()
	icon.texture = load("res://addons/npc_talkkit/icons/npc_talkkit.svg")
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)
	var title := Label.new()
	title.text = "TalkKit workspace"
	title.add_theme_font_size_override("font_size", 13)
	heading.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Write, preview, and manage dialogue"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.modulate.a = 0.65
	heading.add_child(subtitle)
	_open = Button.new()
	_open.text = "Open Editor"
	_open.tooltip_text = "Open this node in the TalkKit main screen"
	_open.pressed.connect(_open_section.bind("conversations"))
	header.add_child(_open)

	_conversation_button = _nav_button(stack,
		"res://addons/npc_talkkit/icons/talk_conversation.svg", "conversations")
	_speaker_button = _nav_button(stack,
		"res://addons/npc_talkkit/icons/talk_speaker.svg", "speakers")
	_box_button = _nav_button(stack,
		"res://addons/npc_talkkit/icons/talk_box_template.svg", "boxes")

	_library = Label.new()
	_library.add_theme_font_size_override("font_size", 10)
	_library.modulate.a = 0.65
	_library.clip_text = true
	_library.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(_library)
	refresh()
	set_process(true)


func _process(_delta: float) -> void:
	var next := _content_signature()
	if next != _signature:
		refresh()


func _nav_button(parent: Control, icon_path: String, section: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.icon = load(icon_path)
	button.expand_icon = false
	button.tooltip_text = "Open %s in the TalkKit workspace" % section
	button.pressed.connect(_open_section.bind(section))
	parent.add_child(button)
	return button


func refresh() -> void:
	if _open == null:
		return
	var enabled := component != null
	_open.disabled = not enabled
	_conversation_button.disabled = not enabled
	_speaker_button.disabled = not enabled
	_box_button.disabled = not enabled
	_conversation_button.text = "Conversations\n%s" % ConversationsSummary.describe(component)
	_speaker_button.text = "Speakers\n%s" % _collection_line(CollectionSummary.Kind.SPEAKERS)
	_box_button.text = "Dialogue Boxes\n%s" % _collection_line(CollectionSummary.Kind.BOXES)
	_speaker_button.tooltip_text = _collection_tooltip(CollectionSummary.Kind.SPEAKERS)
	_box_button.tooltip_text = _collection_tooltip(CollectionSummary.Kind.BOXES)
	_library.text = _library_line()
	_library.tooltip_text = _library_line()
	_signature = _content_signature()


func _collection_line(of_kind: CollectionSummary.Kind) -> String:
	if component == null:
		return "No node"
	var description := CollectionSummary.describe(component, of_kind)
	var names := CollectionSummary.compact_names(component, of_kind)
	return description if names.is_empty() else "%s · %s" % [description, names]


func _collection_tooltip(of_kind: CollectionSummary.Kind) -> String:
	if component == null:
		return "No node"
	var description := CollectionSummary.describe(component, of_kind)
	var names := CollectionSummary.list_names(component, of_kind)
	return description if names.is_empty() else "%s\n%s" % [description, names]


func _library_line() -> String:
	if component == null or component.library == null:
		return "Library · None"
	var path := component.library.resource_path
	return "Library · Local resource" if path.is_empty() else "Library · %s" % path


func _content_signature() -> String:
	if component == null:
		return "none"
	return "%s|%s|%s|%s" % [
		ConversationsSummary.describe(component),
		_collection_line(CollectionSummary.Kind.SPEAKERS),
		_collection_line(CollectionSummary.Kind.BOXES),
		_library_line(),
	]


func _open_section(section: String) -> void:
	if plugin != null and plugin.has_method("open_workspace"):
		plugin.call("open_workspace", component, section)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.025)
	style.border_color = Color(1, 1, 1, 0.09)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
