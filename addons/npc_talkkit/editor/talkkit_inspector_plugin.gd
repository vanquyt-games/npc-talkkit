@tool
extends EditorInspectorPlugin

## Replaces the NPCTalkKit collections in the Inspector with a compact summary
## card, and gives reference slots on lines and conversations a pick-only editor.

const EffectiveRow := preload("res://addons/npc_talkkit/editor/talkkit_effective_row.gd")
const InspectorSummary := preload("res://addons/npc_talkkit/editor/talkkit_inspector_summary.gd")
const ReferenceProperty := preload("res://addons/npc_talkkit/editor/talkkit_reference_property.gd")
const LayerRowProperty := preload("res://addons/npc_talkkit/editor/talkkit_layer_row_property.gd")
const AssetProperty := preload("res://addons/npc_talkkit/editor/talkkit_asset_property.gd")
const NineSliceProperty := preload("res://addons/npc_talkkit/editor/talkkit_nine_slice_property.gd")
const PaddingProperty := preload("res://addons/npc_talkkit/editor/talkkit_padding_property.gd")
const PositionProperty := preload("res://addons/npc_talkkit/editor/talkkit_position_property.gd")
const AutoWidthProperty := preload("res://addons/npc_talkkit/editor/talkkit_auto_width_property.gd")

## A Dialogue Box's layer rows: the slot each lists and its Add button.
const LAYER_ROWS := {
	"panel_decorations": [TalkBoxLayer.Slot.PANEL, "+ Add Decoration"],
	"name_box": [TalkBoxLayer.Slot.SPEAKER_NAME, "+ Add Name Box"],
	"frame": [TalkBoxLayer.Slot.DIALOGUE_VISUAL, "+ Add Frame"],
}

## Pick-only slots and the node collection each picks from. They replace
## Godot's default editor, which would unfold the shared resource inline.
## Placement has no collection, so it keeps a plain picker.
const REFERENCES := {
	"speaker": ReferenceProperty.From.SPEAKERS,
	"dialogue_box": ReferenceProperty.From.BOXES,
	"placement": ReferenceProperty.From.NOWHERE,
	"default_speaker": ReferenceProperty.From.SPEAKERS,
	"default_dialogue_box": ReferenceProperty.From.BOXES,
	"default_placement": ReferenceProperty.From.NOWHERE,
}


## Set by the plugin so summaries and deep links can open the workspace.
var plugin: EditorPlugin
var workspace: Control


func _can_handle(object: Object) -> bool:
	return object is NPCTalkKit or object is TalkLine or object is TalkConversation or object is TalkBoxTemplate or object is TalkBoxLayer


func _parse_begin(object: Object) -> void:
	if object is not NPCTalkKit:
		return
	var summary: MarginContainer = InspectorSummary.new()
	summary.component = object as NPCTalkKit
	summary.plugin = plugin
	add_custom_control(summary)


## The pick-only slots on [param object], or an empty array.
static func references_for(object: Object) -> Array:
	if object is TalkLine:
		return ["speaker", "dialogue_box", "placement"]
	if object is TalkConversation:
		return ["default_speaker", "default_dialogue_box", "default_placement"]
	return []


func _parse_property(
	object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	hint_string: String,
	_usage_flags: int,
	_wide: bool,
) -> bool:
	# A box and its layers are edited as content, not as scripted objects.
	if (object is TalkBoxTemplate or object is TalkBoxLayer) and name == "script":
		return true
	# The Panel's base is edited through its Appearance rows, never as a raw layer.
	if object is TalkBoxTemplate and name == "base":
		return true
	if object is TalkBoxTemplate:
		return _parse_box_property(object as TalkBoxTemplate, name, hint_string)
	if object is TalkBoxLayer:
		if name == "position":
			add_property_editor(name, PositionProperty.new())
			return true
		return _parse_look_property(name, hint_string)

	# The summary card from _parse_begin covers these; hide the raw arrays.
	if object is NPCTalkKit and name in ["conversations", "speakers", "dialogue_boxes"]:
		return true

	# Returning true replaces the default editor.
	if references_for(object).has(name):
		var slot: EditorProperty = ReferenceProperty.new()
		slot.setup(hint_string, REFERENCES[name], plugin)
		add_property_editor(name, slot)
		return true

	# An empty placement means "use the box's own"; the row says so.
	if name == "quick_say_placement":
		var placement: HBoxContainer = EffectiveRow.new()
		placement.component = object as NPCTalkKit
		placement.kind = EffectiveRow.Kind.PLACEMENT
		add_custom_control(placement)
	return false


# A Dialogue Box's custom rows and the notes that explain what applies.
func _parse_box_property(template: TalkBoxTemplate, name: String, hint_string := "") -> bool:
	if LAYER_ROWS.has(name):
		var row: EditorProperty = LayerRowProperty.new()
		var slot: TalkBoxLayer.Slot = LAYER_ROWS[name][0]
		row.setup(slot, LAYER_ROWS[name][1])
		# Under a single name box's or frame's controls, the row is about layers.
		var single := slot != TalkBoxLayer.Slot.PANEL and template.layers_for(slot).size() == 1
		add_property_editor(name, row, false, "Layers" if single else "")
		return true
	if _parse_look_property(name, hint_string):
		return true
	if name == "tail_width":
		add_property_editor(name, AutoWidthProperty.new())
		return true
	if name in ["tail_texture", "continue_texture"]:
		var picker: EditorProperty = AssetProperty.new()
		picker.setup("Texture2D")
		add_property_editor(name, picker)
		return true
	match name:
		"theme":
			add_custom_control(_note("A Theme controls fonts, font sizes and text colours. The Panel, padding and layers always apply."))
		"font", "name_font":
			if template.theme != null:
				add_custom_control(_note("Controlled by Theme: font, size and colour below are read-only."))
		"tail_color":
			add_custom_control(_sample_button(template))
		"renderer":
			add_custom_control(_note("For layouts the settings and layers cannot describe. A custom renderer receives layers for the parts it has."))
	return false


# The shared Look controls: the same editor for the same property, whether it
# belongs to the Panel, a layer, or a name box shown in the settings.
func _parse_look_property(name: String, hint_string := "") -> bool:
	if name.ends_with("nine_slice_texture") or name.ends_with("image_texture") or name.ends_with("_resource") or name == "resource":
		var picker: EditorProperty = AssetProperty.new()
		var base_type := hint_string
		if base_type.is_empty():
			base_type = "StyleBox,Texture2D" if name.ends_with("resource") else "Texture2D"
		picker.setup(base_type)
		add_property_editor(name, picker)
		return true
	if name.ends_with("nine_slice_margins"):
		add_property_editor(name, NineSliceProperty.new())
		return true
	if name.ends_with("padding_mode"):
		add_property_editor(name, PaddingProperty.new(), false, "Padding")
		return true
	return false


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate.a = 0.7
	label.add_theme_font_size_override("font_size", 12)
	return label


# Sets the tail colour to the textured Panel's own colour, undoably.
func _sample_button(template: TalkBoxTemplate) -> Control:
	var row := HBoxContainer.new()
	var button := Button.new()
	button.text = "Sample panel colour"
	button.tooltip_text = "Use the colour at the centre of the Panel's image."
	button.pressed.connect(func() -> void:
		var undo := EditorInterface.get_editor_undo_redo()
		undo.create_action("Sample panel colour", UndoRedo.MERGE_DISABLE, template)
		undo.add_do_property(template, &"tail_color", template.panel_color())
		undo.add_undo_property(template, &"tail_color", template.tail_color)
		undo.add_do_method(template, &"emit_changed")
		undo.add_undo_method(template, &"emit_changed")
		undo.commit_action())
	row.add_child(button)
	return row
