@tool
## Helpers for the folding sections of an embedded EditorInspector. Godot
## exposes no folding API to scripts, so a section is opened by clicking its
## header, and sections are found by their place in the tree.
extends RefCounted


## The top-level sections, in the order their groups are declared.
static func top_sections(inspector: Control) -> Array:
	if inspector == null:
		return []
	var all := inspector.find_children("*", "EditorInspectorSection", true, false)
	var top: Array = []
	for section in all:
		var nested := false
		var node: Node = section.get_parent()
		while node != null and node != inspector:
			if node.get_class() == "EditorInspectorSection":
				nested = true
				break
			node = node.get_parent()
		if not nested:
			top.append(section)
	return top


## The first section nested inside [param section], such as a subgroup.
static func first_subsection(section: Control) -> Control:
	var found := section.find_children("*", "EditorInspectorSection", true, false)
	return found[0] if not found.is_empty() else null


static func is_open(section: Control) -> bool:
	for child in section.get_children():
		if child is VBoxContainer:
			return (child as Control).visible
	return true


## Opens [param section] if it is folded. Awaitable.
static func open(inspector: ScrollContainer, section: Control) -> void:
	if section == null or is_open(section) or not section.is_inside_tree():
		return
	# The header has to be on screen to be clicked.
	inspector.ensure_control_visible(section)
	await section.get_tree().process_frame
	var header := section.get_global_rect().position + Vector2(24.0, 8.0)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = header
		click.global_position = header
		section.get_viewport().push_input(click)
	await section.get_tree().process_frame


## Hides the Add Metadata button, which has nothing to offer here, and the
## header of any class whose properties are all hidden.
static func hide_metadata_button(inspector: Control) -> void:
	if inspector == null:
		return
	for button in inspector.find_children("*", "Button", true, false):
		if (button as Button).text == "Add Metadata":
			(button as Button).visible = false
	for category in inspector.find_children("*", "EditorInspectorCategory", true, false):
		var parent := category.get_parent()
		var next := category.get_index() + 1
		var empty := true
		while next < parent.get_child_count():
			var sibling := parent.get_child(next)
			if sibling.get_class() == "EditorInspectorCategory":
				break
			if _shows_something(sibling):
				empty = false
				break
			next += 1
		(category as Control).visible = not empty


# True for a visible property or section, or a container holding one.
static func _shows_something(node: Node) -> bool:
	if node is not Control or not (node as Control).visible:
		return false
	if node is EditorProperty or node.get_class() == "EditorInspectorSection":
		return true
	for child in node.get_children():
		if _shows_something(child):
			return true
	return false
