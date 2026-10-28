@tool
## Inspector row that summarises a node's conversations in place of the raw
## `conversations` array, with a button that opens the TalkKit workspace.
extends MarginContainer

var component: NPCTalkKit
## Set by the plugin; used to open the workspace.
var plugin: EditorPlugin
var workspace: Control

var _summary: Label


## The TalkConversation class icon.
const ICON := "res://addons/npc_talkkit/icons/talk_conversation.svg"


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_spaced(row)

	var icon := TextureRect.new()
	icon.texture = load(ICON)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)

	# A custom control has no property label of its own.
	var name_label := Label.new()
	name_label.text = "Conversations"
	column.add_child(name_label)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 11)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.modulate.a = 0.7
	column.add_child(_summary)

	var edit := Button.new()
	edit.text = "Open"
	edit.tooltip_text = "Open the TalkKit workspace"
	edit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	edit.pressed.connect(_open_editor)
	row.add_child(edit)

	refresh()


func refresh() -> void:
	if _summary == null:
		return
	_summary.text = describe(component)


## One-line description of [param node]'s conversations and line count.
static func describe(node: NPCTalkKit) -> String:
	if node == null:
		return "No node"
	var conversations := 0
	var lines := 0
	for conversation in node.conversations:
		if conversation == null:
			continue
		conversations += 1
		lines += conversation.lines.size()
	# A node with no conversations is valid: say() needs nothing authored.
	if conversations == 0:
		return "No saved conversations — say() works without them"
	return "%d conversation%s · %d line%s" % [
		conversations, "" if conversations == 1 else "s",
		lines, "" if lines == 1 else "s",
	]


func _open_editor() -> void:
	if plugin != null and plugin.has_method("open_workspace"):
		plugin.call("open_workspace", component, "conversations")


## Adds [param row] with vertical margin, separating it from neighbouring
## Inspector rows.
func _spaced(row: Control) -> void:
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)
	add_child(row)
