@tool
## A Decorations, Name Box or Frame row in a Dialogue Box's settings: the
## slot's layers as links into the Layers view, and an Add button.
extends EditorProperty

var slot: TalkBoxLayer.Slot = TalkBoxLayer.Slot.PANEL
var add_text := "+ Add"

var _row: HFlowContainer


func _init() -> void:
	_row = HFlowContainer.new()
	_row.add_theme_constant_override("h_separation", 6)
	add_child(_row)


func setup(for_slot: TalkBoxLayer.Slot, button_text: String) -> void:
	slot = for_slot
	add_text = button_text


func _update_property() -> void:
	for child in _row.get_children():
		child.queue_free()
	var template := get_edited_object() as TalkBoxTemplate
	if template == null:
		return
	# One row for every slot: what is there, then Open in Layers and Add.
	var layers := template.layers_for(slot)
	var summary := _dim("None" if layers.is_empty() else "%d layer%s" % [layers.size(), "" if layers.size() == 1 else "s"])
	summary.tooltip_text = describe(slot, layers)
	summary.mouse_filter = Control.MOUSE_FILTER_PASS
	_row.add_child(summary)
	var manager := _manager()
	if manager == null:
		_row.add_child(_dim("Edit in the TalkKit workspace."))
		return
	if not layers.is_empty():
		_row.add_child(_button("Open in Layers", func() -> void:
			if layers.size() == 1:
				manager.call("open_layers_at", layers[0])
			else:
				manager.call("open_layers_for", slot)))
	_row.add_child(_button(add_text, func() -> void: manager.call("add_layer_from_settings", slot)))


## The layers on a slot, for the summary's tooltip.
static func describe(for_slot: TalkBoxLayer.Slot, layers: Array) -> String:
	if layers.is_empty():
		return "None"
	var count := "%d layer%s" % [layers.size(), "" if layers.size() == 1 else "s"]
	if for_slot != TalkBoxLayer.Slot.PANEL:
		var names: Array[String] = []
		for layer in layers:
			names.append(layer.name)
		return "%s: %s" % [count, ", ".join(names)]
	var fills := 0
	var edges := 0
	var corners := 0
	for layer in layers:
		if layer.position == TalkBoxLayer.Position.FILL:
			fills += 1
		elif layer.is_corner():
			corners += 1
		else:
			edges += 1
	var parts: Array[String] = []
	for part in [[fills, "fill"], [edges, "edge"], [corners, "corner"]]:
		if part[0] > 0:
			parts.append("%d %s" % part)
	return "%s: %s" % [count, ", ".join(parts)]


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _dim(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate.a = 0.65
	return label


# The box manager hosting this inspector, or null in Godot's own Inspector.
func _manager() -> Node:
	var node := get_parent()
	while node != null and not node.has_method("add_layer_from_settings"):
		node = node.get_parent()
	return node
