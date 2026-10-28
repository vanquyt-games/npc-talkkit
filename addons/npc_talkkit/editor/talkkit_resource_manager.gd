@tool
extends HSplitContainer

## One owning editor for either the node's Speakers or Dialogue Boxes.
## Conversation and line screens only select these resources; mutations live here.

signal changed

enum Kind { SPEAKERS, BOXES }
enum { ACTION_DUPLICATE, ACTION_SHARE, ACTION_PRESET, ACTION_UNIQUE, ACTION_REMOVE }
enum { PRESET_CLASSIC, PRESET_BUBBLE, PRESET_TERMINAL, PRESET_BLANK, PRESET_LOAD, PRESET_FOLDER }
## Presets found in the project's preset folder take ids from here.
const PRESET_USER_FIRST := 100
## Where Save as Preset writes and + New looks for the project's own presets.
const PRESET_FOLDER_SETTING := "npc_talkkit/dialogue_boxes/preset_folder"
const PRESET_FOLDER_DEFAULT := "res://talkkit_presets"

const Summary := preload("res://addons/npc_talkkit/editor/talkkit_collection_summary.gd")
const InlinePreview := preload("res://addons/npc_talkkit/editor/talkkit_inline_preview.gd")
const AnatomyOverlay := preload("res://addons/npc_talkkit/editor/talkkit_anatomy_overlay.gd")
const LayersView := preload("res://addons/npc_talkkit/editor/talkkit_layers_view.gd")
const AddLayerDialog := preload("res://addons/npc_talkkit/editor/talkkit_add_layer_dialog.gd")
const Sections := preload("res://addons/npc_talkkit/editor/talkkit_inspector_sections.gd")

const PRESET_PATHS := {
	PRESET_CLASSIC: "res://addons/npc_talkkit/templates/classic_panel.tres",
	PRESET_BUBBLE: "res://addons/npc_talkkit/templates/speech_bubble.tres",
	PRESET_TERMINAL: "res://addons/npc_talkkit/templates/terminal.tres",
}
## The settings group each part of the box opens, by its first property.
const SLOT_PROPERTIES := {
	"panel": "panel_appearance",
	"text": "font",
	"name": "name_shown",
	"visual": "visual_shown",
	"tail": "tail_shown",
	"continue": "continue_shown",
}
const SAMPLE_TEXT := "Before you go—will you help us find the relay?"

var component: NPCTalkKit
var kind: Kind = Kind.SPEAKERS
var editor_plugin: EditorPlugin

var _title: Label
var _list: ItemList
var _inspector: EditorInspector
var _scope: Label
var _usage: Label
var _actions_popup: PopupMenu
var _preview_title: Label
var _live_preview: TextureRect
var _preview_card: PanelContainer
var _preview_visual: TextureRect
var _preview_name: Label
var _preview_text: Label
var _preview_meta: Label
var _voice_button: Button
var _voice_player: AudioStreamPlayer
var _selected: Resource
var _updating := false

# Dialogue Boxes only.
var _settings: VBoxContainer
var _layers_button: Button
var _layers_view: VBoxContainer
var _add_dialog: ConfirmationDialog
var _anatomy: Control
var _anatomy_button: Button
var _expand_button: Button
var _pending_flash := ""
var _pending_layer: TalkBoxLayer
var _watched: TalkBoxTemplate
var _expanded: Window


func _ready() -> void:
	split_offset = _saved_split("%s_list" % _kind_key(), 230)
	dragged.connect(_save_split.bind("%s_list" % _kind_key()))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	refresh()


func _build() -> void:
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 190
	add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left_panel.add_child(left)

	var header := HBoxContainer.new()
	left.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 14)
	header.add_child(_title)
	if kind == Kind.SPEAKERS:
		var add := Button.new()
		add.text = "+ New"
		add.pressed.connect(_add)
		header.add_child(add)
	else:
		var add_box := MenuButton.new()
		add_box.text = "+ New"
		add_box.tooltip_text = "Create from a visual preset"
		var presets := add_box.get_popup()
		presets.about_to_popup.connect(_fill_presets.bind(presets))
		_fill_presets(presets)
		presets.id_pressed.connect(_on_preset)
		header.add_child(add_box)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	_list.item_clicked.connect(_on_list_clicked)
	_list.gui_input.connect(_on_list_input)
	left.add_child(_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	left.add_child(actions)
	_button(actions, "Load…", _load_entry)
	var more := MenuButton.new()
	more.text = "Actions"
	var popup := more.get_popup()
	popup.add_item("Duplicate", ACTION_DUPLICATE)
	popup.add_item("Save as Shared…", ACTION_SHARE)
	if kind == Kind.BOXES:
		popup.add_item("Save as Preset…", ACTION_PRESET)
	popup.add_item("Make Unique", ACTION_UNIQUE)
	popup.add_separator()
	popup.add_item("Remove", ACTION_REMOVE)
	popup.id_pressed.connect(_on_action)
	actions.add_child(more)
	_actions_popup = popup

	var content_split := HSplitContainer.new()
	content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_split.split_offset = _saved_split("%s_editor" % _kind_key(), 520)
	content_split.dragged.connect(_save_split.bind("%s_editor" % _kind_key()))
	add_child(content_split)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_split.add_child(right)

	_settings = VBoxContainer.new()
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_settings)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 8)
	_settings.add_child(summary)
	_scope = Label.new()
	_scope.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scope.clip_text = true
	_scope.add_theme_font_size_override("font_size", 12)
	summary.add_child(_scope)
	_usage = Label.new()
	_usage.add_theme_font_size_override("font_size", 11)
	_usage.modulate.a = 0.7
	summary.add_child(_usage)
	if kind == Kind.BOXES:
		_layers_button = Button.new()
		_layers_button.text = "Layers · 0"
		_layers_button.tooltip_text = "Decorations on the Panel, Speaker Name and Dialogue Visual"
		_layers_button.pressed.connect(open_layers)
		summary.add_child(_layers_button)

	# EditorInspector exists only in the editor; elsewhere a fallback is used.
	if Engine.is_editor_hint():
		_inspector = EditorInspector.create_default_inspector(null)
		_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_inspector.property_edited.connect(_on_property_edited)
		_inspector.property_selected.connect(_on_property_selected)
		_settings.add_child(_inspector)
	else:
		var fallback := Label.new()
		fallback.text = "Resource properties are available in the Godot editor."
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_settings.add_child(fallback)

	if kind == Kind.BOXES:
		_layers_view = LayersView.new()
		_layers_view.editor_plugin = editor_plugin
		_layers_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_layers_view.visible = false
		_layers_view.back_requested.connect(show_settings)
		_layers_view.panel_requested.connect(func() -> void: focus_slot("panel"))
		_layers_view.add_requested.connect(func(prefill: Dictionary) -> void: open_add_layer(prefill, "layers"))
		_layers_view.layers_changed.connect(_on_layers_changed)
		_layers_view.layer_selected.connect(_on_layer_selected)
		right.add_child(_layers_view)
		_add_dialog = AddLayerDialog.new()
		_add_dialog.layer_created.connect(_on_layer_created)
		add_child(_add_dialog)

	var preview := VBoxContainer.new()
	preview.custom_minimum_size.x = 320
	preview.add_theme_constant_override("separation", 10)
	content_split.add_child(preview)

	var preview_header := HBoxContainer.new()
	preview.add_child(preview_header)
	_preview_title = Label.new()
	_preview_title.text = "Preview"
	_preview_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_title.add_theme_font_size_override("font_size", 13)
	preview_header.add_child(_preview_title)
	if kind == Kind.BOXES:
		_anatomy_button = Button.new()
		_anatomy_button.text = "Anatomy"
		_anatomy_button.toggle_mode = true
		_anatomy_button.tooltip_text = "Label the parts of the box. Hover to learn a part, click to edit it."
		_anatomy_button.toggled.connect(show_anatomy)
		preview_header.add_child(_anatomy_button)
		_expand_button = Button.new()
		_expand_button.text = "Expand"
		_expand_button.tooltip_text = "Open a larger Anatomy Map"
		_expand_button.visible = false
		_expand_button.pressed.connect(open_expanded_anatomy)
		preview_header.add_child(_expand_button)
	_live_preview = InlinePreview.new()
	_live_preview.refreshed.connect(_on_preview_refreshed)
	preview.add_child(_live_preview)
	if kind == Kind.BOXES:
		_live_preview.custom_minimum_size.y = 200
		_anatomy = AnatomyOverlay.new()
		_anatomy.preview = _live_preview
		_anatomy.slot_clicked.connect(_on_anatomy_slot)
		_anatomy.position_clicked.connect(_on_anatomy_position)
		_live_preview.add_child(_anatomy)

	_preview_card = PanelContainer.new()
	_preview_card.custom_minimum_size = Vector2(230, 190)
	preview.add_child(_preview_card)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	_preview_card.add_child(card)

	_preview_visual = TextureRect.new()
	_preview_visual.custom_minimum_size = Vector2(0, 88)
	_preview_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(_preview_visual)
	_preview_name = Label.new()
	_preview_name.add_theme_font_size_override("font_size", 15)
	card.add_child(_preview_name)
	_preview_text = Label.new()
	_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(_preview_text)

	_preview_meta = Label.new()
	_preview_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_meta.modulate.a = 0.68
	_preview_meta.add_theme_font_size_override("font_size", 11)
	preview.add_child(_preview_meta)
	_voice_button = Button.new()
	_voice_button.text = "▶ Preview voice blip"
	_voice_button.pressed.connect(_play_voice_preview)
	preview.add_child(_voice_button)
	_voice_player = AudioStreamPlayer.new()
	add_child(_voice_player)


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func refresh() -> void:
	if _list == null:
		return
	_updating = true
	_title.text = "Speakers" if kind == Kind.SPEAKERS else "Dialogue Boxes"
	var wanted := _selected
	_list.clear()
	var entries := _entries()
	for index in entries.size():
		var entry: Resource = entries[index]
		var label := Summary.entry_name(entry, _summary_kind())
		if _is_shared(entry):
			label += "   ⇗ shared"
		_list.add_item(label)
		_list.set_item_metadata(index, index)
	var at := entries.find(wanted)
	if at < 0 and not entries.is_empty():
		at = 0
	if at >= 0:
		_list.select(at)
		_select(entries[at])
	else:
		_select(null)
	_updating = false


func select_resource(resource: Resource) -> void:
	_selected = resource
	refresh()


func _kind_key() -> String:
	return "speakers" if kind == Kind.SPEAKERS else "boxes"


func _saved_split(key: String, fallback: int) -> int:
	if not Engine.is_editor_hint():
		return fallback
	var settings := EditorInterface.get_editor_settings()
	var path := "npc_talkkit/layout/%s" % key
	return int(settings.get_setting(path)) if settings.has_setting(path) else fallback


func _save_split(offset: int, key: String) -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_setting("npc_talkkit/layout/%s" % key, offset)


func _entries() -> Array:
	if component == null:
		return []
	return component.speakers if kind == Kind.SPEAKERS else component.dialogue_boxes


func _summary_kind() -> Summary.Kind:
	return Summary.Kind.SPEAKERS if kind == Kind.SPEAKERS else Summary.Kind.BOXES


func _on_selected(row: int) -> void:
	if _updating:
		return
	var index := int(_list.get_item_metadata(row))
	var entries := _entries()
	_select(entries[index] if index >= 0 and index < entries.size() else null)


func _select(resource: Resource) -> void:
	var changed_box := resource != _selected
	_selected = resource
	_watch(resource as TalkBoxTemplate)
	if _inspector != null and (changed_box or _inspector.get_edited_object() != resource):
		_inspector.edit(resource)
		if resource is TalkBoxTemplate and is_inside_tree():
			_unfold_panel()
	if _layers_view != null:
		_layers_view.set_template(resource as TalkBoxTemplate)
		if resource == null:
			show_settings()
	_update_layers_button()
	if resource == null:
		_scope.text = "Create or load a resource to edit it here."
		_usage.text = ""
		_refresh_preview()
		return
	_scope.text = resource.resource_path if _is_shared(resource) else "Local to %s" % component.name
	var used := Summary.usage_count(component, resource, _summary_kind())
	_usage.text = "%d use%s on this node" % [used, "" if used == 1 else "s"]
	_refresh_preview()


func _refresh_preview() -> void:
	if _preview_card == null:
		return
	_preview_title.text = "Preview"
	_preview_visual.texture = null
	_preview_visual.visible = kind == Kind.SPEAKERS
	_preview_name.text = ""
	_preview_name.remove_theme_color_override("font_color")
	_preview_name.remove_theme_font_size_override("font_size")
	_preview_name.add_theme_font_size_override("font_size", 15)
	_preview_text.text = "Select a resource to preview it."
	_preview_text.remove_theme_color_override("font_color")
	_preview_text.remove_theme_font_size_override("font_size")
	_preview_meta.text = ""
	_voice_button.visible = false
	_preview_card.remove_theme_stylebox_override("panel")
	_live_preview.visible = false
	if _selected == null:
		return
	var used := Summary.usage_count(component, _selected, _summary_kind())
	var scope := "Shared resource" if _is_shared(_selected) else "Local resource"
	_preview_meta.text = "%s\nUsed %d time%s on this node" % [scope, used, "" if used == 1 else "s"]
	if kind == Kind.SPEAKERS:
		_refresh_speaker_preview(_selected as TalkSpeaker)
	else:
		var box := _selected as TalkBoxTemplate
		_preview_title.text = "Dialogue box preview"
		_preview_meta.text += "\n%s open · %s close · %.2fs" % [
			box.open_transition, box.close_transition, box.transition_duration]
	_refresh_runtime_preview()


func _refresh_runtime_preview() -> void:
	if component == null or _selected == null:
		return
	var sample := TalkConversation.new()
	sample.conversation_id = &"editor_preview"
	var sample_line := TalkLine.new()
	sample_line.text = SAMPLE_TEXT
	if kind == Kind.SPEAKERS:
		sample.default_speaker = _selected as TalkSpeaker
		sample.default_dialogue_box = (
			component.dialogue_boxes[0] if not component.dialogue_boxes.is_empty()
			else NPCTalkKit.default_template())
	else:
		sample.default_dialogue_box = _selected as TalkBoxTemplate
		sample.default_speaker = component.speakers[0] if not component.speakers.is_empty() else _sample_speaker()
	sample.lines = [sample_line]
	_live_preview.set_preview(component, sample, sample_line)
	_live_preview.visible = true
	# The live preview shows the box; this card only holds voice and scope notes.
	_preview_card.visible = false


func _refresh_speaker_preview(speaker: TalkSpeaker) -> void:
	if speaker == null:
		return
	_preview_title.text = "Speaker preview"
	_preview_name.text = speaker.display_name if not speaker.display_name.is_empty() else "Narrator / unnamed"
	_preview_text.text = (
		"Voice blips enabled" if speaker.voice_enabled and speaker.voice_blip != null
		else "No voice preview configured"
	)
	_voice_button.visible = true
	_voice_button.disabled = not speaker.voice_enabled or speaker.voice_blip == null
	var visual := speaker.resolve_visual()
	if visual == null:
		_preview_visual.visible = false
		return
	if visual.texture != null:
		_preview_visual.texture = visual.texture
		return
	if visual.sprite_frames != null and visual.sprite_frames.has_animation(visual.animation):
		if visual.sprite_frames.get_frame_count(visual.animation) > 0:
			_preview_visual.texture = visual.sprite_frames.get_frame_texture(visual.animation, 0)
	_preview_visual.visible = _preview_visual.texture != null


func _play_voice_preview() -> void:
	var speaker := _selected as TalkSpeaker
	if speaker == null or not speaker.voice_enabled or speaker.voice_blip == null:
		return
	_voice_player.stream = speaker.voice_blip
	_voice_player.pitch_scale = (speaker.voice_pitch_min + speaker.voice_pitch_max) * 0.5
	_voice_player.play()


func _add() -> void:
	if component == null:
		return
	var created: Resource
	if kind == Kind.SPEAKERS:
		var speaker := TalkSpeaker.new()
		speaker.display_name = "New speaker"
		created = speaker
	else:
		var box := NPCTalkKit.default_template().duplicate(true) as TalkBoxTemplate
		box.resource_name = "Classic Panel"
		created = box
	var entries := _entries().duplicate()
	entries.append(created)
	_commit_entries("Create %s" % ("speaker" if kind == Kind.SPEAKERS else "dialogue box"), entries, created)


func _on_preset(id: int) -> void:
	if id == PRESET_LOAD:
		_load_entry()
		return
	if id == PRESET_FOLDER:
		_show_preset_folder()
		return
	var path: String = PRESET_PATHS.get(id, "")
	if id >= PRESET_USER_FIRST:
		var found := user_presets()
		path = found[id - PRESET_USER_FIRST] if id - PRESET_USER_FIRST < found.size() else ""
	var created: TalkBoxTemplate
	if id == PRESET_BLANK:
		created = TalkBoxTemplate.new()
		created.resource_name = "Blank Custom"
	else:
		var source := load(path) as TalkBoxTemplate if not path.is_empty() else null
		if source == null:
			return
		created = Summary.fresh_copy(source) as TalkBoxTemplate
		if created.resource_name.is_empty():
			created.resource_name = path.get_file().get_basename().capitalize()
	var entries := _entries().duplicate()
	entries.append(created)
	_commit_entries("Create dialogue box from preset", entries, created)


func _fill_presets(menu: PopupMenu) -> void:
	menu.clear()
	menu.add_item("Classic Panel", PRESET_CLASSIC)
	menu.add_item("Speech Bubble", PRESET_BUBBLE)
	menu.add_item("Terminal", PRESET_TERMINAL)
	var found := user_presets()
	if not found.is_empty():
		menu.add_separator("Your presets")
		for index in found.size():
			menu.add_item(preset_name(found[index]), PRESET_USER_FIRST + index)
			menu.set_item_tooltip(-1, found[index])
	menu.add_separator()
	menu.add_item("Blank Custom", PRESET_BLANK)
	menu.add_item("Load Existing…", PRESET_LOAD)
	menu.add_item("Show Presets Folder", PRESET_FOLDER)


## The folder of the project's own presets.
static func preset_folder() -> String:
	var folder := String(ProjectSettings.get_setting(PRESET_FOLDER_SETTING, PRESET_FOLDER_DEFAULT))
	return folder.trim_suffix("/") if not folder.is_empty() else PRESET_FOLDER_DEFAULT


## Adds the preset folder to Project Settings, so it can be moved.
static func register_preset_setting() -> void:
	if not ProjectSettings.has_setting(PRESET_FOLDER_SETTING):
		ProjectSettings.set_setting(PRESET_FOLDER_SETTING, PRESET_FOLDER_DEFAULT)
	ProjectSettings.set_initial_value(PRESET_FOLDER_SETTING, PRESET_FOLDER_DEFAULT)
	ProjectSettings.add_property_info({
		"name": PRESET_FOLDER_SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_DIR,
	})


## Every dialogue box saved in the preset folder, by path, sorted by file name.
static func user_presets() -> Array[String]:
	var found: Array[String] = []
	var folder := preset_folder()
	if not DirAccess.dir_exists_absolute(folder):
		return found
	var files := Array(DirAccess.get_files_at(folder))
	files.sort()
	for file: String in files:
		var path := folder.path_join(file.trim_suffix(".remap"))
		# Reads the header only, so listing never loads every preset's textures.
		if path.ends_with(".tres") and FileAccess.get_file_as_string(path).get_slice("\n", 0).contains("script_class=\"TalkBoxTemplate\""):
			found.append(path)
	return found


## A preset's name: its resource name, or its file name.
static func preset_name(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var main := text.substr(maxi(0, text.find("\n[resource]")))
	var at := main.find("\nresource_name = \"")
	if at >= 0:
		var start := at + "\nresource_name = \"".length()
		return main.substr(start, main.find("\"", start) - start)
	return path.get_file().get_basename().capitalize()


func _confirm_save_preset() -> void:
	var box := _selected as TalkBoxTemplate
	if box == null:
		return
	if not Engine.is_editor_hint():
		save_preset(box, Summary.entry_name(box, _summary_kind()))
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Save as Preset"
	dialog.ok_button_text = "Save"
	var body := VBoxContainer.new()
	dialog.add_child(body)
	var title := LineEdit.new()
	title.text = Summary.entry_name(box, _summary_kind())
	title.select_all_on_focus = true
	body.add_child(title)
	var note := Label.new()
	note.modulate.a = 0.7
	body.add_child(note)
	var describe := func(text: String) -> void:
		var path := _preset_path(text)
		note.text = ("Replaces the preset in %s" if FileAccess.file_exists(path) else "Saved to %s") % path
		dialog.ok_button_text = "Replace" if FileAccess.file_exists(path) else "Save"
		dialog.get_ok_button().disabled = text.strip_edges().is_empty()
	title.text_changed.connect(describe)
	describe.call(title.text)
	title.text_submitted.connect(func(_text: String) -> void:
		if not dialog.get_ok_button().disabled:
			dialog.hide()
			dialog.confirmed.emit())
	dialog.confirmed.connect(func() -> void:
		save_preset(box, title.text.strip_edges())
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 0))
	title.grab_focus()


## Saves a copy of [param box] as a preset named [param title]. The box itself
## stays as it is: a preset is a starting point, not a shared resource.
func save_preset(box: TalkBoxTemplate, title: String) -> Error:
	var folder := preset_folder()
	DirAccess.make_dir_recursive_absolute(folder)
	var preset := Summary.fresh_copy(box) as TalkBoxTemplate
	preset.resource_name = title
	var path := _preset_path(title)
	var error := ResourceSaver.save(preset, path)
	if error == OK and Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().update_file(path)
		EditorInterface.get_resource_filesystem().scan()
	return error


static func _preset_path(title: String) -> String:
	var file := title.strip_edges().to_snake_case().validate_filename()
	return preset_folder().path_join((file if not file.is_empty() else "preset") + ".tres")


func _show_preset_folder() -> void:
	if not Engine.is_editor_hint():
		return
	var folder := preset_folder()
	DirAccess.make_dir_recursive_absolute(folder)
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.get_file_system_dock().navigate_to_path(folder + "/")


func _duplicate() -> void:
	if _selected == null or component == null:
		return
	var copy := Summary.fresh_copy(_selected)
	if kind == Kind.SPEAKERS:
		var speaker := copy as TalkSpeaker
		speaker.display_name += " copy"
		speaker.speaker_id = &""
	else:
		copy.resource_name = Summary.entry_name(_selected, _summary_kind()) + " copy"
	var entries := _entries().duplicate()
	entries.append(copy)
	_commit_entries("Duplicate %s" % ("speaker" if kind == Kind.SPEAKERS else "dialogue box"), entries, copy)


func _make_unique() -> void:
	if _selected == null or not _is_shared(_selected):
		return
	var copy := Summary.fresh_copy(_selected)
	var entries := _entries().duplicate()
	var at := entries.find(_selected)
	if at >= 0:
		entries[at] = copy
	_commit_entries("Make resource unique", entries, copy)


## Removes the selected entry. Every conversation default and line that named
## it switches to [param replacement], in the same undo step, so nothing is
## left pointing at a box or speaker the node no longer lists.
func _remove(replacement: Resource = null) -> void:
	if _selected == null or component == null:
		return
	var entries := _entries().duplicate()
	var at := entries.find(_selected)
	if at < 0:
		return
	entries.remove_at(at)
	var uses := Summary.usages(component, _selected, _summary_kind())
	var next: Resource = entries[mini(at, entries.size() - 1)] if not entries.is_empty() else null
	var property: StringName = &"speakers" if kind == Kind.SPEAKERS else &"dialogue_boxes"
	if Engine.is_editor_hint() and editor_plugin != null:
		var undo := editor_plugin.get_undo_redo()
		undo.create_action("Remove %s" % ("speaker" if kind == Kind.SPEAKERS else "dialogue box"),
			UndoRedo.MERGE_DISABLE, component)
		undo.add_do_property(component, property, entries)
		undo.add_undo_property(component, property, component.get(property))
		for use in uses:
			undo.add_do_property(use["object"], use["property"], replacement)
			undo.add_undo_property(use["object"], use["property"], _selected)
		undo.add_do_method(self, &"_after_entries_changed", next)
		undo.add_undo_method(self, &"_after_entries_changed", _selected)
		undo.commit_action()
		return
	component.set(property, entries)
	for use in uses:
		(use["object"] as Object).set(use["property"], replacement)
	_after_entries_changed(next)


func _on_list_clicked(index: int, _at: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_RIGHT or _actions_popup == null:
		return
	_list.select(index)
	_on_selected(index)
	_actions_popup.position = Vector2i(get_screen_position() + get_local_mouse_position())
	_actions_popup.popup()


func _on_list_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_confirm_remove()
		_list.accept_event()


func _on_action(id: int) -> void:
	match id:
		ACTION_DUPLICATE: _duplicate()
		ACTION_SHARE: _share()
		ACTION_PRESET: _confirm_save_preset()
		ACTION_UNIQUE: _make_unique()
		ACTION_REMOVE: _confirm_remove()


func _confirm_remove() -> void:
	if _selected == null:
		return
	var uses := Summary.usages(component, _selected, _summary_kind())
	if uses.is_empty() or not Engine.is_editor_hint():
		_remove()
		return
	var speakers := kind == Kind.SPEAKERS
	var dialog := ConfirmationDialog.new()
	dialog.title = "Remove %s?" % Summary.entry_name(_selected, _summary_kind())
	dialog.ok_button_text = "Remove"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	dialog.add_child(body)
	var shown := uses.slice(0, 6).map(func(use: Dictionary) -> String: return "• " + use["label"])
	if uses.size() > shown.size():
		shown.append("• and %d more" % (uses.size() - shown.size()))
	var used := Label.new()
	used.text = "Used in %d place%s on %s:\n%s" % [
		uses.size(), "" if uses.size() == 1 else "s", component.name, "\n".join(shown)]
	body.add_child(used)
	var row := HBoxContainer.new()
	body.add_child(row)
	var caption := Label.new()
	caption.text = "Use instead"
	row.add_child(caption)
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var others: Array[Resource] = []
	for entry in _entries():
		if entry != _selected and entry != null:
			others.append(entry)
			choice.add_item(Summary.entry_name(entry, _summary_kind()))
	choice.add_item("None (narrator)" if speakers else "None (the shipped Classic Panel)")
	row.add_child(choice)
	if _is_shared(_selected):
		var note := Label.new()
		note.text = "The shared file stays on disk."
		note.modulate.a = 0.7
		body.add_child(note)
	dialog.confirmed.connect(func() -> void:
		var picked := choice.selected
		_remove(others[picked] if picked < others.size() else null)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 0))


func _load_entry() -> void:
	if component == null or not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Speaker" if kind == Kind.SPEAKERS else "Dialogue box")
	dialog.file_selected.connect(func(path: String) -> void:
		var loaded := load(path)
		var entries := _entries().duplicate()
		if kind == Kind.SPEAKERS and loaded is TalkSpeaker:
			entries.append(loaded)
			_commit_entries("Load speaker", entries, loaded)
		elif kind == Kind.BOXES and loaded is TalkBoxTemplate:
			entries.append(loaded)
			_commit_entries("Load dialogue box", entries, loaded)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_file_dialog()


func _share() -> void:
	if _selected == null or not Engine.is_editor_hint():
		return
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Speaker" if kind == Kind.SPEAKERS else "Dialogue box")
	dialog.current_file = "%s.tres" % Summary.entry_name(_selected, _summary_kind()).to_snake_case()
	dialog.file_selected.connect(func(path: String) -> void:
		if ResourceSaver.save(_selected, path) == OK:
			var saved := load(path)
			var entries := _entries().duplicate()
			var at := entries.find(_selected)
			if at >= 0:
				entries[at] = saved
			_commit_entries("Save resource as shared", entries, saved)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_file_dialog()


func _on_property_edited(property: StringName) -> void:
	if _selected != null:
		_selected.emit_changed()
	changed.emit()
	_select(_selected)
	_flash_after_refresh(slot_for_property(String(property)))


func _on_property_selected(property: String) -> void:
	var slot := slot_for_property(property)
	if not slot.is_empty() and _anatomy != null:
		_anatomy.flash_slot(slot)


func _touch() -> void:
	changed.emit()
	refresh()


func _commit_entries(action: String, after: Array, selected: Resource) -> void:
	if component == null:
		return
	var property: StringName = &"speakers" if kind == Kind.SPEAKERS else &"dialogue_boxes"
	var before: Array = component.get(property)
	if Engine.is_editor_hint() and editor_plugin != null:
		var undo := editor_plugin.get_undo_redo()
		undo.create_action(action, UndoRedo.MERGE_DISABLE, component)
		undo.add_do_property(component, property, after)
		undo.add_undo_property(component, property, before)
		undo.add_do_method(self, &"_after_entries_changed", selected)
		undo.add_undo_method(self, &"_after_entries_changed", _selected)
		undo.commit_action()
		return
	component.set(property, after)
	_after_entries_changed(selected)


func _after_entries_changed(selected: Resource) -> void:
	_selected = selected
	_touch()


static func _is_shared(resource: Resource) -> bool:
	if resource == null:
		return false
	return not resource.resource_path.is_empty() and not resource.resource_path.contains("::")


#region Dialogue Box layers and the Anatomy Map

## The part of the box a settings property belongs to, for the preview
## highlight: "panel", "text", "name", "visual", "tail", "continue", or "".
static func slot_for_property(property: String) -> String:
	if property.begins_with("frame_"):
		return "visual"
	if property.begins_with("name_"):
		return "name"
	if property in ["frame"] or property.begins_with("visual_"):
		return "visual"
	if property.begins_with("tail_"):
		return "tail"
	if property.begins_with("continue_"):
		return "continue"
	if property in ["font", "text_size", "text_color", "line_spacing", "text_min_size", "typewriter_speed"]:
		return "text"
	if property.begins_with("panel_") or property == "panel_decorations":
		return "panel"
	return ""


## Shows the settings for the selected box again.
func show_settings() -> void:
	if _settings != null:
		_settings.visible = true
	if _layers_view != null:
		_layers_view.visible = false


## True while the Layers view is showing.
func is_showing_layers() -> bool:
	return _layers_view != null and _layers_view.visible


## Opens the Layers view for the selected box.
func open_layers() -> void:
	if _layers_view == null or _selected == null:
		return
	_settings.visible = false
	_layers_view.visible = true
	_layers_view.set_template(_selected as TalkBoxTemplate)


## Opens the Layers view with [param layer] selected.
func open_layers_at(layer: TalkBoxLayer) -> void:
	open_layers()
	if _layers_view != null:
		_layers_view.select_layer(layer)


## Opens the Layers view with the layers on [param slot], or only those at
## [param position], highlighted.
func open_layers_for(slot: TalkBoxLayer.Slot, position := -1) -> void:
	open_layers()
	if _layers_view != null:
		_layers_view.focus(slot, position)


## Opens Add Layer from a settings row; the user stays in the settings after.
func add_layer_from_settings(slot: TalkBoxLayer.Slot) -> void:
	var from: String = ["Panel › Decorations", "Speaker Name › Name Box", "Dialogue Visual › Frame"][slot]
	open_add_layer({"slot": slot, "from": from}, "settings")


## Opens Add Layer with [param prefill]. [param origin] decides where the user
## lands afterwards: "settings" stays put, "layers" and "anatomy" show the new
## layer in the Layers view.
func open_add_layer(prefill: Dictionary, origin: String) -> void:
	if _add_dialog == null or _selected == null:
		return
	_add_dialog.template = _selected as TalkBoxTemplate
	if Engine.is_editor_hint():
		_add_dialog.open(prefill, origin)
	else:
		_add_dialog.apply_prefill(prefill)
		_add_dialog.origin = origin


## Adds [param layer] to the selected box, then lands where [param origin] says.
func add_layer(layer: TalkBoxLayer, origin: String) -> void:
	var box := _selected as TalkBoxTemplate
	if box == null or _layers_view == null:
		return
	var after := box.layers.duplicate()
	after.append(layer)
	_layers_view.set_template(box)
	_layers_view.commit_layers("Add layer", after, layer)
	if origin == "settings":
		show_settings()
		# The preview rebuilds first; the new layer is outlined once it has.
		_pending_layer = layer
		focus_slot(["panel", "name", "visual"][layer.slot], false)
	else:
		open_layers_at(layer)


func _on_layer_created(layer: TalkBoxLayer, origin: String) -> void:
	add_layer(layer, origin)


func _on_layers_changed() -> void:
	changed.emit()
	if _inspector != null and _selected != null:
		# The layer rows read the template's layers.
		_selected.notify_property_list_changed()
	_update_layers_button()
	_refresh_preview()


func _on_layer_selected(layer: TalkBoxLayer) -> void:
	if _anatomy != null:
		_anatomy.flash_layer(layer)


func _update_layers_button() -> void:
	if _layers_button == null:
		return
	var box := _selected as TalkBoxTemplate
	_layers_button.disabled = box == null
	_layers_button.text = "Layers · %d" % (box.layers.size() if box != null else 0)


## Brings the settings group for [param slot] into view and highlights it. In
## the Layers view a layer slot stays there and highlights its layers instead.
func focus_slot(slot: String, flash_preview := true) -> void:
	if is_showing_layers() and slot in ["panel", "name", "visual"]:
		_layers_view.focus(["panel", "name", "visual"].find(slot) as TalkBoxLayer.Slot)
		if _anatomy != null and flash_preview:
			_anatomy.flash_slot(slot)
		return
	show_settings()
	if _anatomy != null and flash_preview:
		_anatomy.flash_slot(slot)
	if _inspector == null or not SLOT_PROPERTIES.has(slot):
		return
	# An edit may have asked the inspector to rebuild; find the group after.
	await get_tree().process_frame
	await get_tree().process_frame
	await _unfold_group(slot)
	var editor := _property_editor(SLOT_PROPERTIES[slot])
	if is_instance_valid(editor):
		_inspector.ensure_control_visible(editor)
		_flash_control(editor)


## The settings groups in the order the inspector draws them.
const GROUPS := ["panel", "text", "name", "visual", "tail", "continue", "transitions", "advanced"]


# Opens the settings group for [param slot] if it is folded, and a single
# name box's or frame's controls inside it.
func _unfold_group(slot: String) -> void:
	var sections := Sections.top_sections(_inspector)
	var index := GROUPS.find(slot)
	if index < 0 or index >= sections.size():
		return
	await Sections.open(_inspector, sections[index])
	if slot in ["name", "visual"]:
		await Sections.open(_inspector, Sections.first_subsection(sections[index]))


## Opens the Panel group, where a box's look starts.
func _unfold_panel() -> void:
	# A hidden tab cannot be clicked; wait until the manager is shown.
	while is_inside_tree() and not is_visible_in_tree():
		await visibility_changed
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	Sections.hide_metadata_button(_inspector)
	await _unfold_group("panel")


func _property_editor(property: String) -> EditorProperty:
	var stack: Array[Node] = [_inspector]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is EditorProperty and (node as EditorProperty).get_edited_property() == property:
			return node
		stack.append_array(node.get_children())
	return null


func _flash_control(control: Control) -> void:
	var tint := ColorRect.new()
	tint.color = Color(0.35, 0.72, 1.0, 0.35)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.add_child(tint)
	var tween := tint.create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(tint, "modulate:a", 0.0, 0.8)
	tween.finished.connect(tint.queue_free)


## Turns the Anatomy Map on the preview on or off.
func show_anatomy(on: bool) -> void:
	if _anatomy == null:
		return
	_anatomy.template = _selected as TalkBoxTemplate
	_anatomy.set_shown(on)
	if _anatomy_button != null and _anatomy_button.button_pressed != on:
		_anatomy_button.set_pressed_no_signal(on)
	if _expand_button != null:
		_expand_button.visible = on


func _on_anatomy_slot(slot: String) -> void:
	_close_expanded()
	focus_slot(slot)


func _on_anatomy_position(position: TalkBoxLayer.Position) -> void:
	_close_expanded()
	var box := _selected as TalkBoxTemplate
	if box == null:
		return
	var here: Array[TalkBoxLayer] = []
	for layer in box.layers_for(TalkBoxLayer.Slot.PANEL):
		if layer.position == position:
			here.append(layer)
	if here.is_empty():
		open_add_layer({
			"slot": TalkBoxLayer.Slot.PANEL,
			"position": position,
			"depth": TalkBoxLayer.Depth.ABOVE,
			"from": "Anatomy Map › %s" % TalkBoxLayer.POSITION_NAMES[position],
		}, "anatomy")
	elif here.size() == 1:
		open_layers_at(here[0])
	else:
		open_layers_for(TalkBoxLayer.Slot.PANEL, position)


## A larger Anatomy Map with labels drawn outside the box.
func open_expanded_anatomy() -> void:
	if _selected == null or not Engine.is_editor_hint():
		return
	_close_expanded()
	_expanded = Window.new()
	_expanded.title = "Dialogue Box Anatomy"
	_expanded.size = Vector2i(1100, 640)
	_expanded.transient = true
	_expanded.exclusive = false
	_expanded.close_requested.connect(_close_expanded)
	# One root sized to the window, so the preview and the map share a frame.
	var root := ColorRect.new()
	root.color = Color(0.06, 0.08, 0.11)
	_expanded.add_child(root)
	var fit_root := func() -> void: root.size = Vector2(_expanded.size)
	_expanded.size_changed.connect(fit_root)
	var big := InlinePreview.new()
	big.mirror(_live_preview)
	big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big.offset_left = 190
	big.offset_right = -190
	big.offset_top = 120
	big.offset_bottom = -150
	root.add_child(big)
	var map := AnatomyOverlay.new()
	map.preview = big
	map.callouts = true
	map.template = _selected as TalkBoxTemplate
	root.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.slot_clicked.connect(_on_anatomy_slot)
	map.position_clicked.connect(_on_anatomy_position)
	map.set_shown(true)
	add_child(_expanded)
	fit_root.call()
	_expanded.popup_centered()


func _close_expanded() -> void:
	if _expanded != null and is_instance_valid(_expanded):
		_expanded.queue_free()
	_expanded = null


# A node with no speakers still previews a name, so the Speaker Name part and
# its name box can be seen and styled.
static func _sample_speaker() -> TalkSpeaker:
	var speaker := TalkSpeaker.new()
	speaker.display_name = "Speaker"
	return speaker


func _flash_after_refresh(slot: String) -> void:
	_pending_flash = slot


func _on_preview_refreshed() -> void:
	if _layers_view != null:
		var renderer: Node = _live_preview.get_renderer()
		if renderer != null and renderer.has_method("exposed_slots"):
			var slots: Array = renderer.exposed_slots()
			if slots != _layers_view.exposed_slots:
				_layers_view.exposed_slots = slots
				_layers_view.refresh()
	if _anatomy == null:
		return
	_anatomy.template = _selected as TalkBoxTemplate
	if _pending_flash.is_empty() and _pending_layer == null:
		return
	# A fresh renderer settles its layout over the next frames.
	await get_tree().process_frame
	await get_tree().process_frame
	if not _pending_flash.is_empty():
		_anatomy.flash_slot(_pending_flash)
		_pending_flash = ""
	if _pending_layer != null:
		_anatomy.flash_layer(_pending_layer)
		_pending_layer = null


# Edits from outside the inspector, such as undo or the Sample button, still
# refresh the preview.
func _watch(box: TalkBoxTemplate) -> void:
	if _watched == box:
		return
	if _watched != null and _watched.changed.is_connected(_on_watched_changed):
		_watched.changed.disconnect(_on_watched_changed)
	_watched = box
	if box != null:
		box.changed.connect(_on_watched_changed)


func _on_watched_changed() -> void:
	if not is_inside_tree():
		return
	_update_layers_button()
	_refresh_preview.call_deferred()

#endregion
