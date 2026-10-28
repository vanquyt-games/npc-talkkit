@tool
## The Layers view: every decoration on a Dialogue Box, grouped by the slot it
## decorates and by depth, with the selected layer's settings beside the list.
## A drill-in from the box's settings, not a separate mode.
extends VBoxContainer

## The user wants the settings back.
signal back_requested
## The user wants a new layer; [param prefill] holds "slot", "position" and
## "depth" when known.
signal add_requested(prefill: Dictionary)
## The user wants to edit the Base Appearance in the Panel group.
signal panel_requested
## Layers were added, removed, reordered or edited.
signal layers_changed
## A layer was selected, for the preview highlight.
signal layer_selected(layer: TalkBoxLayer)

const HELP_SETTING := "npc_talkkit/ui/layers_help_seen"
const Sections := preload("res://addons/npc_talkkit/editor/talkkit_inspector_sections.gd")
const SLOTS := [TalkBoxLayer.Slot.PANEL, TalkBoxLayer.Slot.SPEAKER_NAME, TalkBoxLayer.Slot.DIALOGUE_VISUAL]
enum { BUTTON_ADD, BUTTON_PANEL, BUTTON_DUPLICATE, BUTTON_REMOVE }
const SHORT_SOURCES := ["Flat", "Nine-slice", "Image", "Resource"]

var template: TalkBoxTemplate
var editor_plugin: EditorPlugin
## Layer slots the box's renderer can draw. Layers on other slots are marked.
var exposed_slots: Array = SLOTS.duplicate()

var _title: Label
var _help: PanelContainer
var _tree: Tree
var _inspector: EditorInspector
var _props_note: Label
var _selected: TalkBoxLayer
## Layers highlighted together, such as all those at one Position.
var _focus: Array[TalkBoxLayer] = []
var _focus_label := ""
var _rebuilding := false


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_build()
	refresh()


func _build() -> void:
	var header := HBoxContainer.new()
	add_child(header)
	var back := Button.new()
	back.text = "← Settings"
	back.tooltip_text = "Back to Dialogue Box settings"
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	header.add_child(_title)
	var add := Button.new()
	add.text = "+ Add Layer"
	add.pressed.connect(func() -> void: add_requested.emit({}))
	header.add_child(add)

	_help = PanelContainer.new()
	var help_box := VBoxContainer.new()
	_help.add_child(help_box)
	var help_text := Label.new()
	help_text.text = "Layers add artwork around the panel, speaker name or portrait."
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_box.add_child(help_text)
	var help_buttons := HBoxContainer.new()
	help_box.add_child(help_buttons)
	var show_map := Button.new()
	show_map.name = "ShowAnatomyMap"
	show_map.text = "View anatomy"
	help_buttons.add_child(show_map)
	var got_it := Button.new()
	got_it.text = "Dismiss"
	got_it.pressed.connect(dismiss_help)
	help_buttons.add_child(got_it)
	show_map.pressed.connect(func() -> void:
		dismiss_help()
		var owner_manager := _manager()
		if owner_manager != null:
			owner_manager.call("show_anatomy", true))
	_help.visible = not _help_seen()
	add_child(_help)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 270
	add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	split.add_child(left)
	_tree = Tree.new()
	_tree.name = "LayerTree"
	_tree.hide_root = true
	# This is navigation, not another inspector. Details belong in the editor
	# beside it and in tooltips, so one column stays useful at narrow widths.
	_tree.columns = 1
	_tree.select_mode = Tree.SELECT_MULTI
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.multi_selected.connect(_on_multi_selected)
	_tree.item_edited.connect(_on_item_edited)
	_tree.button_clicked.connect(_on_button_clicked)
	_tree.set_drag_forwarding(_get_drag, _can_drop, _drop)
	left.add_child(_tree)
	var escape := Label.new()
	escape.text = "Custom Renderer supports fully custom layouts."
	escape.tooltip_text = "Use Advanced › Custom Renderer for animated or non-standard layouts, such as chat threads."
	escape.modulate.a = 0.55
	escape.add_theme_font_size_override("font_size", 11)
	left.add_child(escape)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_props_note = Label.new()
	_props_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_props_note.modulate.a = 0.7
	_props_note.add_theme_font_size_override("font_size", 11)
	right.add_child(_props_note)
	if Engine.is_editor_hint() and editor_plugin != null:
		_inspector = EditorInspector.create_default_inspector(null)
		_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_inspector.property_edited.connect(_on_layer_property_edited)
		right.add_child(_inspector)


func set_template(value: TalkBoxTemplate) -> void:
	if value != template:
		_selected = null
		_focus.clear()
	template = value
	refresh()


## Rebuilds the list from the template.
func refresh() -> void:
	if _tree == null:
		return
	_rebuilding = true
	_tree.clear()
	var root := _tree.create_item()
	if template == null:
		_title.text = "Layers"
		_rebuilding = false
		_show_props()
		return
	_title.text = "Layers · %s" % _box_name()
	for slot in SLOTS:
		var slot_layers: Array[TalkBoxLayer] = []
		for layer in template.layers:
			if layer != null and layer.slot == slot:
				slot_layers.append(layer)
		var group := _tree.create_item(root)
		group.set_text(0, "%s  %d" % [TalkBoxLayer.SLOT_NAMES[slot], slot_layers.size()])
		group.set_selectable(0, false)
		group.set_custom_font_size(0, 14)
		group.add_button(0, _icon("Add"), BUTTON_ADD, false, "Add a layer to %s" % TalkBoxLayer.SLOT_NAMES[slot])
		group.set_metadata(0, {"slot": slot})
		if slot == TalkBoxLayer.Slot.PANEL:
			var base := _tree.create_item(group)
			base.set_text(0, "Base Appearance  ·  %s" % _appearance_name())
			base.set_tooltip_text(0, "The Panel's foundation. Edit it in the Panel group.")
			base.set_selectable(0, false)
			base.set_custom_color(0, Color(1, 1, 1, 0.65))
			base.add_button(0, _icon("Edit"), BUTTON_PANEL, false, "Edit in Panel")
			base.set_metadata(0, {"panel": true})
		for depth in [TalkBoxLayer.Depth.BEHIND, TalkBoxLayer.Depth.ABOVE]:
			var depth_layers: Array[TalkBoxLayer] = []
			for layer in slot_layers:
				if layer.depth == depth:
					depth_layers.append(layer)
			if depth_layers.is_empty():
				continue
			var zone := _tree.create_item(group)
			zone.set_text(0, "Behind" if depth == TalkBoxLayer.Depth.BEHIND else "Above")
			zone.set_custom_color(0, Color(1, 1, 1, 0.5))
			zone.set_custom_font_size(0, 11)
			zone.set_selectable(0, false)
			zone.set_metadata(0, {"slot": slot, "depth": depth})
			for layer in depth_layers:
				_add_layer_item(zone, layer)
	_rebuilding = false
	_restore_selection()
	_show_props()


func _add_layer_item(parent: TreeItem, layer: TalkBoxLayer) -> void:
	var item := _tree.create_item(parent)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, layer.enabled)
	item.set_text(0, layer.name)
	var detail := "%s · %s" % [TalkBoxLayer.POSITION_NAMES[layer.position], TalkBoxLayer.SOURCE_NAMES[layer.visual_source]]
	if not exposed_slots.has(layer.slot):
		detail += " · not shown by this renderer"
		item.set_custom_color(0, Color(1.0, 0.75, 0.35))
	item.set_tooltip_text(0, detail)
	item.add_button(0, _icon("Duplicate"), BUTTON_DUPLICATE, false, "Duplicate")
	item.add_button(0, _icon("Remove"), BUTTON_REMOVE, false, "Remove")
	item.set_metadata(0, {"layer": layer})


## Selects [param layer] and shows its settings.
func select_layer(layer: TalkBoxLayer) -> void:
	_selected = layer
	_focus.clear()
	_focus_label = ""
	_restore_selection()
	_show_props()
	if layer != null:
		layer_selected.emit(layer)


## Highlights every layer on [param slot], or only those at [param position]
## when it is not -1. One match is simply selected.
func focus(slot: TalkBoxLayer.Slot, position := -1) -> void:
	var found: Array[TalkBoxLayer] = []
	for layer in (template.layers if template != null else []):
		if layer != null and layer.slot == slot and (position < 0 or layer.position == position):
			found.append(layer)
	if found.size() == 1:
		select_layer(found[0])
		return
	_selected = null
	_focus = found
	_focus_label = TalkBoxLayer.SLOT_NAMES[slot]
	if position >= 0:
		_focus_label += " › " + TalkBoxLayer.POSITION_NAMES[position]
	_restore_selection()
	_show_props()


## The layers currently highlighted in the list.
func highlighted() -> Array[TalkBoxLayer]:
	if _selected != null:
		return [_selected]
	return _focus.duplicate()


func dismiss_help() -> void:
	_help.visible = false
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_setting(HELP_SETTING, true)


func _help_seen() -> bool:
	if not Engine.is_editor_hint():
		return false
	var settings := EditorInterface.get_editor_settings()
	return settings.has_setting(HELP_SETTING) and bool(settings.get_setting(HELP_SETTING))


func _restore_selection() -> void:
	if _tree == null or _tree.get_root() == null:
		return
	_rebuilding = true
	_tree.deselect_all()
	var wanted := highlighted()
	var first: TreeItem
	for item in _layer_items():
		var layer: TalkBoxLayer = item.get_metadata(0)["layer"]
		if wanted.has(layer):
			item.select(0)
			if first == null:
				first = item
	if first != null:
		_tree.scroll_to_item(first)
	_rebuilding = false


func _show_props() -> void:
	if _selected != null:
		_props_note.text = "%s  ›  %s  ›  %s" % [
			TalkBoxLayer.SLOT_NAMES[_selected.slot],
			"Behind" if _selected.depth == TalkBoxLayer.Depth.BEHIND else "Above",
			SHORT_SOURCES[_selected.visual_source],
		]
		if not exposed_slots.has(_selected.slot):
			_props_note.text += "  ·  Not supported by this renderer"
	elif not _focus.is_empty():
		_props_note.text = "%d layers selected on %s" % [_focus.size(), _focus_label]
	elif _focus_label != "":
		_props_note.text = "No layers on %s" % _focus_label
	else:
		_props_note.text = "Select a layer to edit · Drag to reorder"
	if _inspector != null:
		_inspector.edit(_selected)
		_inspector.visible = _selected != null
		_open_look()


func _layer_items() -> Array[TreeItem]:
	var items: Array[TreeItem] = []
	var stack: Array[TreeItem] = [_tree.get_root()]
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		if item == null:
			continue
		var meta: Variant = item.get_metadata(0)
		if meta is Dictionary and meta.has("layer"):
			items.append(item)
		var child := item.get_first_child()
		var children: Array[TreeItem] = []
		while child != null:
			children.append(child)
			child = child.get_next()
		children.reverse()
		stack.append_array(children)
	return items


func _on_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if _rebuilding or not selected:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary and meta.has("layer"):
		select_layer(meta["layer"])


func _on_item_edited() -> void:
	var item := _tree.get_edited()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is not Dictionary or not meta.has("layer"):
		return
	var layer: TalkBoxLayer = meta["layer"]
	var enabled := item.is_checked(0)
	if enabled != layer.enabled:
		# Tree rejects rebuilds while it is dispatching a mouse edit.
		set_layer_enabled.call_deferred(layer, enabled)


func _on_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button: int) -> void:
	var meta: Dictionary = item.get_metadata(0)
	match id:
		BUTTON_ADD:
			add_requested.emit({"slot": meta["slot"]})
		BUTTON_PANEL:
			panel_requested.emit()
		BUTTON_DUPLICATE:
			duplicate_layer(meta["layer"])
		BUTTON_REMOVE:
			remove_layer(meta["layer"])


func _on_layer_property_edited(_property: String) -> void:
	if _selected != null:
		_selected.emit_changed()
	if template != null:
		template.emit_changed()
	layers_changed.emit()
	# Name, position and source show in the list.
	refresh()


#region Edits

func set_layer_enabled(layer: TalkBoxLayer, enabled: bool) -> void:
	var undo := _undo()
	if undo != null:
		# Keep every operation on this editor control's history. Mixing the
		# scene-owned subresource with this control causes a history mismatch.
		undo.create_action("%s layer" % ("Enable" if enabled else "Disable"), UndoRedo.MERGE_DISABLE, self)
		undo.add_do_method(self, &"_apply_layer_enabled", layer, enabled)
		undo.add_undo_method(self, &"_apply_layer_enabled", layer, layer.enabled)
		undo.commit_action()
		return
	_apply_layer_enabled(layer, enabled)


func _apply_layer_enabled(layer: TalkBoxLayer, enabled: bool) -> void:
	layer.enabled = enabled
	layer.emit_changed()
	_after_edit(layer)


func duplicate_layer(layer: TalkBoxLayer) -> void:
	var copy := layer.duplicate(true) as TalkBoxLayer
	copy.name = layer.name + " copy"
	var after := template.layers.duplicate()
	after.insert(after.find(layer) + 1, copy)
	commit_layers("Duplicate layer", after, copy)


func remove_layer(layer: TalkBoxLayer) -> void:
	var after := template.layers.duplicate()
	after.erase(layer)
	commit_layers("Remove layer", after, null)


## Moves [param layer] before or after [param target], or to the end of a
## depth zone when [param target] is null. Layers stay on their slot.
func move_layer(layer: TalkBoxLayer, target: TalkBoxLayer, after_target: bool, depth: int) -> bool:
	if target != null and target.slot != layer.slot:
		return false
	var order := template.layers.duplicate()
	order.erase(layer)
	var at := order.size()
	if target != null:
		at = order.find(target) + (1 if after_target else 0)
	order.insert(at, layer)
	var new_depth: int = target.depth if target != null else depth
	commit_layers("Move layer", order, layer, {layer: new_depth})
	return true


## Replaces the template's layers in one undoable step and selects
## [param select]. [param depths] maps layers to a new depth in the same step.
func commit_layers(action: String, after: Array, select: TalkBoxLayer, depths := {}) -> void:
	var before := template.layers.duplicate()
	var undo := _undo()
	if undo != null:
		var before_depths := {}
		for layer in depths:
			before_depths[layer] = layer.depth
		undo.create_action(action, UndoRedo.MERGE_DISABLE, self)
		undo.add_do_method(self, &"_apply_layers", _typed(after), depths, select)
		undo.add_undo_method(self, &"_apply_layers", _typed(before), before_depths,
			_selected if before.has(_selected) else null)
		undo.commit_action()
		return
	_apply_layers(_typed(after), depths, select)


func _apply_layers(items: Array[TalkBoxLayer], depths: Dictionary, select: TalkBoxLayer) -> void:
	for layer in depths:
		layer.depth = depths[layer]
	template.layers = items
	_after_edit(select)


func _after_edit(select: TalkBoxLayer) -> void:
	if template != null:
		template.emit_changed()
		template.notify_property_list_changed()
	_selected = select if template != null and template.layers.has(select) else null
	_focus.clear()
	# Button and checkbox signals are emitted while Tree is locked. Rebuild on
	# the next frame so edits remain safe from both mouse and Undo/Redo paths.
	refresh.call_deferred()
	layers_changed.emit()
	if _selected != null:
		layer_selected.emit(_selected)


static func _typed(list: Array) -> Array[TalkBoxLayer]:
	var typed: Array[TalkBoxLayer] = []
	for layer in list:
		if layer is TalkBoxLayer:
			typed.append(layer)
	return typed

#endregion


#region Drag and drop

func _get_drag(at: Vector2) -> Variant:
	var item := _tree.get_item_at_position(at)
	if item == null:
		return null
	var meta: Variant = item.get_metadata(0)
	if meta is not Dictionary or not meta.has("layer"):
		return null
	var preview := Label.new()
	preview.text = (meta["layer"] as TalkBoxLayer).name
	_tree.set_drag_preview(preview)
	_tree.drop_mode_flags = Tree.DROP_MODE_INBETWEEN | Tree.DROP_MODE_ON_ITEM
	return {"talkkit_layer": meta["layer"]}


func _can_drop(at: Vector2, data: Variant) -> bool:
	return _drop_target(at, data) != null


func _drop(at: Vector2, data: Variant) -> void:
	var target: Variant = _drop_target(at, data)
	_tree.drop_mode_flags = Tree.DROP_MODE_DISABLED
	if target == null:
		return
	move_layer(data["talkkit_layer"], target["layer"], target["after"], target["depth"])


# Where a drop at [param at] would put the dragged layer, or null.
func _drop_target(at: Vector2, data: Variant) -> Variant:
	if data is not Dictionary or not data.has("talkkit_layer"):
		return null
	var dragged: TalkBoxLayer = data["talkkit_layer"]
	var item := _tree.get_item_at_position(at)
	if item == null:
		return null
	var meta: Variant = item.get_metadata(0)
	if meta is not Dictionary:
		return null
	if meta.has("layer"):
		var target: TalkBoxLayer = meta["layer"]
		if target == dragged or target.slot != dragged.slot:
			return null
		return {"layer": target, "after": _tree.get_drop_section_at_position(at) > 0, "depth": target.depth}
	if meta.has("depth") and meta["slot"] == dragged.slot:
		return {"layer": null, "after": true, "depth": meta["depth"]}
	return null

#endregion


func _box_name() -> String:
	if not template.resource_name.is_empty():
		return template.resource_name
	if not template.resource_path.is_empty() and not template.resource_path.contains("::"):
		return template.resource_path.get_file().get_basename().capitalize()
	return "Dialogue Box"


func _appearance_name() -> String:
	return SHORT_SOURCES[template.base.visual_source] if template.base != null else ""


func _undo() -> EditorUndoRedoManager:
	if Engine.is_editor_hint() and editor_plugin != null:
		return editor_plugin.get_undo_redo()
	return null


func _manager() -> Node:
	var node := get_parent()
	while node != null and not node.has_method("show_anatomy"):
		node = node.get_parent()
	return node


func _icon(icon_name: String) -> Texture2D:
	if Engine.is_editor_hint():
		var base := EditorInterface.get_base_control()
		if base != null and base.has_theme_icon(icon_name, &"EditorIcons"):
			return base.get_theme_icon(icon_name, &"EditorIcons")
	return PlaceholderTexture2D.new()


# Tidies the layer's inspector once it is built.
func _open_look() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if _inspector == null or not is_instance_valid(_inspector):
		return
	Sections.hide_metadata_button(_inspector)
