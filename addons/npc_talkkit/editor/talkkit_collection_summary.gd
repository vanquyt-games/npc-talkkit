@tool
## Wording and bookkeeping for a node's speakers and dialogue boxes: their
## names, where they are used, and fresh copies for presets and duplicates.
extends RefCounted

enum Kind { SPEAKERS, BOXES }


static func describe(node: NPCTalkKit, of_kind: Kind) -> String:
	if node == null:
		return "No node"
	var count := _entries(node, of_kind).size()
	if of_kind == Kind.SPEAKERS:
		# An empty collection is valid: say() needs nothing declared.
		if count == 0:
			return "No speakers — lines show no name and no face"
		return "%d speaker%s" % [count, "" if count == 1 else "s"]
	if count == 0:
		return "No dialogue boxes — add one before writing a conversation"
	return "%d box%s" % [count, "" if count == 1 else "es"]


## The entries' names, joined for display.
static func list_names(node: NPCTalkKit, of_kind: Kind) -> String:
	if node == null:
		return ""
	var names: Array[String] = []
	for entry in _entries(node, of_kind):
		names.append(entry_name(entry, of_kind))
	return " · ".join(names)


## A bounded name list for compact UI. The complete list belongs in a tooltip.
static func compact_names(node: NPCTalkKit, of_kind: Kind, limit := 3) -> String:
	if node == null:
		return ""
	var entries := _entries(node, of_kind)
	var names: Array[String] = []
	for index in mini(entries.size(), limit):
		names.append(entry_name(entries[index], of_kind))
	var remaining := entries.size() - names.size()
	if remaining > 0:
		names.append("+%d more" % remaining)
	return " · ".join(names)


## Display name of one entry: a speaker's display name, or a box's resource
## name or file name.
static func entry_name(entry: Resource, of_kind: Kind) -> String:
	if entry == null:
		return "(empty)"
	if of_kind == Kind.SPEAKERS:
		var speaker := entry as TalkSpeaker
		if speaker == null:
			return "(not a speaker)"
		if not speaker.display_name.is_empty():
			return speaker.display_name
		if not speaker.speaker_id.is_empty():
			return String(speaker.speaker_id)
		return "(unnamed)"
	if not entry.resource_name.is_empty():
		return entry.resource_name
	var path := entry.resource_path
	if path.is_empty() or path.contains("::"):
		return "(local box)"
	return path.get_file().get_basename().capitalize()


static func _entries(node: NPCTalkKit, of_kind: Kind) -> Array:
	return node.speakers if of_kind == Kind.SPEAKERS else node.dialogue_boxes


## How many conversation defaults and lines on [param node] reference
## [param entry].
static func usage_count(node: NPCTalkKit, entry: Resource, of_kind: Kind) -> int:
	return usages(node, entry, of_kind).size()


## Every conversation default and line on [param node] that names
## [param entry], as {"object", "property", "label"}.
static func usages(node: NPCTalkKit, entry: Resource, of_kind: Kind) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if node == null or entry == null:
		return found
	var on_conversation: StringName = &"default_speaker" if of_kind == Kind.SPEAKERS else &"default_dialogue_box"
	var on_line: StringName = &"speaker" if of_kind == Kind.SPEAKERS else &"dialogue_box"
	for conversation in node.conversations:
		if conversation == null:
			continue
		var title := String(conversation.conversation_id)
		if conversation.get(on_conversation) == entry:
			found.append({"object": conversation, "property": on_conversation, "label": "%s · default" % title})
		for index in conversation.lines.size():
			var line: TalkLine = conversation.lines[index]
			if line != null and line.get(on_line) == entry:
				found.append({"object": line, "property": on_line, "label": "%s · line %d" % [title, index + 1]})
	return found


## A deep copy whose built-in sub-resources are new and unnamed, while files
## such as textures stay shared. duplicate(true) in the editor tries to give
## the copies the original sub-resources' paths and fails on every one.
static func fresh_copy(original: Resource) -> Resource:
	var copy: Resource = original.get_script().new() if original.get_script() != null \
		else ClassDB.instantiate(original.get_class())
	for property in original.get_property_list():
		var name: String = property.name
		if not property.usage & PROPERTY_USAGE_STORAGE or name in ["resource_path", "script"]:
			continue
		copy.set(name, _fresh_value(original.get(name)))
	return copy


static func _fresh_value(value: Variant) -> Variant:
	if value is Resource:
		var path: String = (value as Resource).resource_path
		return fresh_copy(value) if path.is_empty() or path.contains("::") else value
	if value is Array:
		var list: Array = (value as Array).duplicate()
		for index in list.size():
			list[index] = _fresh_value(list[index])
		return list
	return value
