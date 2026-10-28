@tool
## Adds a layer to a Dialogue Box: pick the slot, the Position, the Visual
## Source and, optionally, the resource. Whatever the caller already knows is
## filled in.
extends ConfirmationDialog

## A layer was made. [param origin] is what the caller passed to [method open].
signal layer_created(layer: TalkBoxLayer, origin: String)

const PositionGrid := preload("res://addons/npc_talkkit/editor/talkkit_position_grid.gd")
const SOURCE_LABELS := ["Flat", "Nine-slice", "Image", "Existing"]
const SOURCE_HINTS := [
	"Color, border and rounded corners.",
	"A resizable frame or pixel-art panel.",
	"An ornament, edge, badge or atlas region.",
	"Reuse a StyleBox or texture from this project.",
]

var slot: TalkBoxLayer.Slot = TalkBoxLayer.Slot.PANEL
var layer_position: TalkBoxLayer.Position = TalkBoxLayer.Position.TOP_LEFT
var source: TalkBoxLayer.Source = TalkBoxLayer.Source.IMAGE
var depth: TalkBoxLayer.Depth = TalkBoxLayer.Depth.ABOVE
## The picked texture or StyleBox, or null to choose later.
var resource: Resource
## Where the dialog was opened from, passed back with the layer.
var origin := ""
## The box the layer is for, to mark Positions that already hold layers.
var template: TalkBoxTemplate

var _prefill_note: Label
var _slot_option: OptionButton
var _position_grid: HBoxContainer
var _source_buttons: Array[Button] = []
var _source_hint: Label
var _depth_option: OptionButton
var _picker_row: HBoxContainer
var _picker: Control


func _init() -> void:
	title = "Add Layer"
	ok_button_text = "Add Layer"
	min_size = Vector2i(440, 0)
	confirmed.connect(_on_confirmed)
	_build()


func _build() -> void:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	_prefill_note = Label.new()
	_prefill_note.modulate = Color(0.6, 0.8, 1.0)
	body.add_child(_prefill_note)

	_slot_option = OptionButton.new()
	for index in TalkBoxLayer.SLOT_NAMES.size():
		_slot_option.add_item(TalkBoxLayer.SLOT_NAMES[index], index)
	_slot_option.item_selected.connect(func(index: int) -> void:
		slot = index as TalkBoxLayer.Slot
		_sync())
	body.add_child(_row("Target", _slot_option))

	_position_grid = PositionGrid.new()
	_position_grid.position_chosen.connect(func(spot: TalkBoxLayer.Position) -> void:
		layer_position = spot
		_sync())
	var position_box := _position_grid
	body.add_child(_row("Anchor", position_box))

	body.add_child(_section_label("Appearance"))

	var sources := GridContainer.new()
	sources.columns = 2
	sources.add_theme_constant_override("h_separation", 6)
	sources.add_theme_constant_override("v_separation", 6)
	var source_group := ButtonGroup.new()
	for index in TalkBoxLayer.SOURCE_NAMES.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = source_group
		button.text = SOURCE_LABELS[index]
		button.tooltip_text = "%s — %s" % [TalkBoxLayer.SOURCE_NAMES[index], SOURCE_HINTS[index]]
		button.custom_minimum_size = Vector2(190, 36)
		button.pressed.connect(func() -> void:
			source = index as TalkBoxLayer.Source
			resource = null
			_sync())
		sources.add_child(button)
		_source_buttons.append(button)
	body.add_child(sources)
	_source_hint = Label.new()
	_source_hint.modulate.a = 0.7
	_source_hint.add_theme_font_size_override("font_size", 11)
	body.add_child(_source_hint)

	_picker_row = HBoxContainer.new()
	body.add_child(_picker_row)

	_depth_option = OptionButton.new()
	_depth_option.add_item("Behind content", TalkBoxLayer.Depth.BEHIND)
	_depth_option.add_item("Above content", TalkBoxLayer.Depth.ABOVE)
	_depth_option.item_selected.connect(func(index: int) -> void: depth = index as TalkBoxLayer.Depth)
	body.add_child(_row("Draw order", _depth_option))


## Fills the dialog from [param prefill] ("slot", "position", "depth",
## "source", "from") and shows it.
func open(prefill: Dictionary, from_origin: String) -> void:
	apply_prefill(prefill)
	origin = from_origin
	_sync()
	popup_centered()


## Sets the fields from what the caller knows; the rest gets a sensible default.
func apply_prefill(prefill: Dictionary) -> void:
	slot = prefill.get("slot", TalkBoxLayer.Slot.PANEL)
	var is_panel := slot == TalkBoxLayer.Slot.PANEL
	layer_position = prefill.get("position", TalkBoxLayer.Position.TOP_LEFT if is_panel else TalkBoxLayer.Position.FILL)
	if prefill.has("depth"):
		depth = prefill["depth"]
	else:
		depth = TalkBoxLayer.Depth.BEHIND if slot == TalkBoxLayer.Slot.SPEAKER_NAME else TalkBoxLayer.Depth.ABOVE
	if prefill.has("source"):
		source = prefill["source"]
	else:
		var image_spot := is_panel and layer_position != TalkBoxLayer.Position.FILL
		source = TalkBoxLayer.Source.IMAGE if image_spot else TalkBoxLayer.Source.NINE_SLICE
	resource = null
	var from: String = prefill.get("from", "")
	if _prefill_note != null:
		_prefill_note.text = "From %s" % from if not from.is_empty() else ""
		_prefill_note.visible = not from.is_empty()


## The layer the current choices describe.
func build_layer() -> TalkBoxLayer:
	return make_layer(slot, layer_position, source, depth, resource)


## A new layer with a name that says what it is.
static func make_layer(
	for_slot: TalkBoxLayer.Slot,
	at: TalkBoxLayer.Position,
	with_source: TalkBoxLayer.Source,
	at_depth: TalkBoxLayer.Depth,
	picked: Resource = null,
) -> TalkBoxLayer:
	var layer := TalkBoxLayer.new()
	layer.slot = for_slot
	layer.position = at
	layer.depth = at_depth
	layer.visual_source = with_source
	layer.name = default_name(for_slot, at, with_source)
	match with_source:
		TalkBoxLayer.Source.NINE_SLICE:
			var style := layer.style as StyleBoxTexture
			if picked is Texture2D:
				style.texture = picked
				var margin := floorf(minf(picked.get_width(), picked.get_height()) / 3.0)
				style.set_texture_margin_all(maxf(1.0, margin))
			elif picked is StyleBoxTexture:
				layer.style = picked
		TalkBoxLayer.Source.IMAGE:
			if picked is Texture2D:
				layer.texture = picked
		TalkBoxLayer.Source.RESOURCE:
			if picked is StyleBox:
				layer.style = picked
			elif picked is Texture2D:
				layer.texture = picked
	return layer


static func default_name(for_slot: TalkBoxLayer.Slot, at: TalkBoxLayer.Position, with_source: TalkBoxLayer.Source) -> String:
	if for_slot == TalkBoxLayer.Slot.SPEAKER_NAME:
		return "Name Box"
	if for_slot == TalkBoxLayer.Slot.DIALOGUE_VISUAL:
		return "Portrait Frame" if at == TalkBoxLayer.Position.FILL else "Portrait %s" % TalkBoxLayer.POSITION_NAMES[at]
	if at == TalkBoxLayer.Position.FILL:
		return "Background" if with_source != TalkBoxLayer.Source.NINE_SLICE else "Frame"
	if at >= TalkBoxLayer.Position.TOP_LEFT:
		return "%s Ornament" % TalkBoxLayer.POSITION_NAMES[at]
	return "%s Edge" % TalkBoxLayer.POSITION_NAMES[at]


func _sync() -> void:
	if _slot_option == null:
		return
	_slot_option.select(slot)
	_position_grid.set_chosen(layer_position)
	var taken: Array = []
	if template != null:
		for layer in template.layers_for(slot):
			taken.append(layer.position)
	_position_grid.set_taken(taken)
	_source_buttons[source].button_pressed = true
	for index in _source_buttons.size():
		_style_choice(_source_buttons[index], index == source)
	_source_hint.text = SOURCE_HINTS[source]
	_depth_option.select(depth)
	_rebuild_picker()


# Flat Style starts from a new StyleBoxFlat; the others take a resource.
func _rebuild_picker() -> void:
	for child in _picker_row.get_children():
		child.queue_free()
	_picker = null
	if source == TalkBoxLayer.Source.FLAT_STYLE:
		return
	var label := Label.new()
	label.text = "Asset"
	label.custom_minimum_size.x = 80
	_picker_row.add_child(label)
	if not Engine.is_editor_hint():
		return
	var picker := EditorResourcePicker.new()
	picker.base_type = "StyleBox,Texture2D" if source == TalkBoxLayer.Source.RESOURCE else "Texture2D"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.edited_resource = resource
	picker.resource_changed.connect(func(value: Resource) -> void: resource = value)
	_picker_row.add_child(picker)
	_picker = picker
	var later := Label.new()
	later.text = "Optional"
	later.modulate.a = 0.6
	_picker_row.add_child(later)


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate.a = 0.75
	label.add_theme_font_size_override("font_size", 11)
	return label


func _on_confirmed() -> void:
	layer_created.emit(build_layer(), origin)


# The chosen card is filled with the accent colour, so the choice is obvious.
static func _style_choice(button: Button, chosen: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.bg_color = Color(0.34, 0.6, 0.95, 0.35) if chosen else Color(1, 1, 1, 0.05)
	style.border_color = Color(0.34, 0.6, 0.95) if chosen else Color(1, 1, 1, 0.12)
	style.set_border_width_all(2 if chosen else 1)
	for state in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
