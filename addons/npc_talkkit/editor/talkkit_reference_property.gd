@tool
## Inspector slot for a resource reference: pick one, or open the picked one
## where it is edited. It does not unfold the resource for in-place editing,
## since that would edit a shared file from a line's Overrides.
##
## Keeps [EditorResourcePicker] for drag-and-drop, quick-load and conversion.
## A note under the slot says how far an edit to the picked resource reaches.
extends EditorProperty

## Which of the node's collections this slot picks from, if any. Placement has
## no collection, so its slot uses the plain picker.
enum From { SPEAKERS, BOXES, NOWHERE }

const BROWSE := 9000
const CLEAR := 9001
const FIRST := 0

var _from: From = From.NOWHERE
var _base_type := ""
var _plugin: EditorPlugin
var _choices: OptionButton
var _picker: EditorResourcePicker
var _link: Button
var _scope: Label
## Set while applying an incoming value, so it is not written back and the
## scene is not marked dirty on every selection change.
var _updating := false


## [param base_type] is the class the slot accepts, which the Inspector passes
## as the property's hint string.
func setup(base_type: String, from: From = From.NOWHERE, plugin: EditorPlugin = null) -> void:
	_base_type = base_type
	_from = from
	_plugin = plugin

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)

	if _from == From.NOWHERE:
		_picker = EditorResourcePicker.new()
		_picker.base_type = base_type
		_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_picker.resource_changed.connect(_on_picked)
		row.add_child(_picker)
		add_focusable(_picker)
	else:
		# Offer the node's own collection; Godot's picker does not list it.
		_choices = OptionButton.new()
		_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_choices.clip_text = true
		_choices.fit_to_longest_item = false
		_choices.item_selected.connect(_on_chosen)
		row.add_child(_choices)
		add_focusable(_choices)

	_link = Button.new()
	_link.text = "Edit ↗"
	_link.flat = true
	_link.add_theme_font_size_override("font_size", 11)
	_link.pressed.connect(_open)
	row.add_child(_link)

	_scope = Label.new()
	_scope.add_theme_font_size_override("font_size", 11)
	_scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scope.modulate.a = 0.7
	add_child(_scope)
	set_bottom_editor(_scope)


func _update_property() -> void:
	_updating = true
	var value: Resource = get_edited_object().get(get_edited_property())
	if _picker != null:
		_picker.edited_resource = value
	if _choices != null:
		_fill(value)
	_link.disabled = value == null
	_link.tooltip_text = describe_link(value)
	_scope.text = describe_scope(value, _scene_root())
	_scope.visible = not _scope.text.is_empty()
	_updating = false


func _scene_root() -> Node:
	return EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null


#region Wording

static func describe_link(value: Resource) -> String:
	if value == null:
		return "Nothing picked yet — choose one first, then open it here"
	return "Open this resource in its TalkKit workspace manager"


## How far an edit to this resource would reach: a shared resource changes for
## every line and NPC that points at it.
static func describe_scope(value: Resource, root: Node = null) -> String:
	if value == null:
		return ""
	var places := usage_in_scene(value, root)
	if not _is_shared(value):
		if places > 1:
			return "Used in %d places in this scene. Edit ↗ changes all of them." % places
		return "Lives in this scene."
	var file := value.resource_path.get_file()
	if places > 1:
		return "%s — shared. Used in %d places here; Edit ↗ changes all of them, and any other scene using it." % [file, places]
	return "%s — shared. Edit ↗ changes it for every scene using it." % file


## A resource saved to its own file, as opposed to one living in the scene.
static func _is_shared(value: Resource) -> bool:
	var path := value.resource_path
	return not path.is_empty() and not path.contains("::")


## How many conversations and lines in [param root] point at [param value].
static func usage_in_scene(value: Resource, root: Node) -> int:
	if value == null or root == null:
		return 0
	var count := 0
	for node in _talkkits(root):
		for conversation in node.conversations:
			if conversation == null:
				continue
			if conversation.default_speaker == value or conversation.default_dialogue_box == value \
					or conversation.default_placement == value:
				count += 1
			for line in conversation.lines:
				if line == null:
					continue
				if line.speaker == value or line.dialogue_box == value or line.placement == value:
					count += 1
	return count


static func _talkkits(node: Node) -> Array[NPCTalkKit]:
	var found: Array[NPCTalkKit] = []
	if node is NPCTalkKit:
		found.append(node)
	for child in node.get_children():
		found.append_array(_talkkits(child))
	return found

#endregion


#region Picking from the node's collection

## Everything the owning node carries, plus the current value when it is not in
## that list, so it stays visible and selected.
func _fill(value: Resource) -> void:
	_choices.clear()
	var entries := collection(owner_node(), _from)
	for index in entries.size():
		_choices.add_item(entry_name(entries[index]), FIRST + index)
	var at := entries.find(value)
	if value != null and at < 0:
		_choices.add_item("%s  ·  not in this node's list" % entry_name(value), FIRST + entries.size())
		at = entries.size()
	if _choices.item_count > 0:
		_choices.add_separator()
	_choices.add_item("Browse…", BROWSE)
	_choices.add_item("Clear", CLEAR)
	_choices.selected = _choices.get_item_index(FIRST + at) if at >= 0 else -1


func _on_chosen(index: int) -> void:
	if _updating:
		return
	var id := _choices.get_item_id(index)
	if id == CLEAR:
		emit_changed(get_edited_property(), null)
		return
	if id == BROWSE:
		_browse()
		return
	var entries := collection(owner_node(), _from)
	var at := id - FIRST
	# The extra entry past the end is the value that is not in the list; it is
	# already selected, so re-picking it changes nothing.
	if at >= 0 and at < entries.size():
		emit_changed(get_edited_property(), entries[at])
	else:
		_update_property()


func _browse() -> void:
	if not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", _base_type)
	dialog.file_selected.connect(func(path: String) -> void:
		var loaded := load(path)
		if loaded != null and loaded.is_class("Resource"):
			emit_changed(get_edited_property(), loaded)
		_update_property()
		dialog.queue_free())
	dialog.canceled.connect(func() -> void:
		_update_property()
		dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_file_dialog()


## The NPCTalkKit whose conversations contain the object being edited, found
## by searching the edited scene. A TalkLine has no reference to its node.
static func owner_of(object: Object, root: Node) -> NPCTalkKit:
	if object == null or root == null:
		return null
	for node in _talkkits(root):
		for conversation in node.conversations:
			if conversation == null:
				continue
			if conversation == object:
				return node
			for line in conversation.lines:
				if line == object:
					return node
	return null


func owner_node() -> NPCTalkKit:
	return owner_of(get_edited_object(), _scene_root())


static func collection(node: NPCTalkKit, from: From) -> Array:
	if node == null:
		return []
	if from == From.SPEAKERS:
		return node.speakers
	if from == From.BOXES:
		return node.dialogue_boxes
	return []


## What one entry is called in the list.
static func entry_name(value: Resource) -> String:
	if value == null:
		return "(empty)"
	if value is TalkSpeaker:
		var speaker := value as TalkSpeaker
		if not speaker.display_name.is_empty():
			return speaker.display_name
		if not speaker.speaker_id.is_empty():
			return String(speaker.speaker_id)
		return "(unnamed)"
	if not value.resource_name.is_empty():
		return value.resource_name
	var path := value.resource_path
	if path.is_empty() or path.contains("::"):
		return "(local)"
	return path.get_file().get_basename().capitalize()

#endregion


func _on_picked(value: Resource) -> void:
	if _updating:
		return
	emit_changed(get_edited_property(), value)


func _open() -> void:
	var value: Resource = get_edited_object().get(get_edited_property())
	if value == null or not Engine.is_editor_hint():
		return
	var owner := owner_node()
	if _plugin != null and _plugin.has_method("open_workspace") and owner != null:
		if value is TalkSpeaker:
			_plugin.call("open_workspace", owner, "speakers", value)
			return
		if value is TalkBoxTemplate:
			_plugin.call("open_workspace", owner, "boxes", value)
			return
	EditorInterface.edit_resource(value)
