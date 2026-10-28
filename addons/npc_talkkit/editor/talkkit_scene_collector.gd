@tool
class_name TalkKitSceneCollector
extends RefCounted

## Gathers conversations and speakers from the NPCTalkKit nodes in a scene, so
## [TalkValidator] can check inline content together with a library.


## One place a conversation id was declared.
class Declaration extends RefCounted:
	var id: StringName
	var conversation: TalkConversation
	## Scene-relative node path, or "(library)".
	var where: String
	var from_library := false


class Collected extends RefCounted:
	var speakers: Array[TalkSpeaker] = []
	## Unique instances, so shared content is validated once.
	var conversations: Array[TalkConversation] = []
	var declarations: Array[Declaration] = []


## Walks [param root] plus an optional [param library] and returns everything
## that should be validated together.
static func collect(root: Node, library: TalkKitDatabase = null) -> Collected:
	var out := Collected.new()
	if library != null:
		for speaker in library.speakers:
			if speaker != null and not out.speakers.has(speaker):
				out.speakers.append(speaker)
		for conversation in library.conversations:
			if conversation == null:
				continue
			if not out.conversations.has(conversation):
				out.conversations.append(conversation)
			_record(out, conversation, "(library)", true)
	if root != null:
		_walk(root, root, out)
	return out


## Validates a scene and its library as one body of content.
##
## Conversation ids are per node: several NPCs may each own a "greeting". Only
## the library is a single id namespace.
static func validate(root: Node, library: TalkKitDatabase = null) -> TalkValidationReport:
	var collected := collect(root, library)
	var report := TalkValidationReport.new()

	# Only speakers with an id can collide.
	var speaker_ids: Dictionary = {}
	for speaker in collected.speakers:
		report.merge(TalkValidator.validate_speaker(speaker))
		if speaker == null or speaker.speaker_id.is_empty():
			continue
		if speaker_ids.has(speaker.speaker_id):
			report.add(&"DUPLICATE_SPEAKER_ID", &"error",
				"Duplicate speaker id '%s'." % speaker.speaker_id,
				{"speaker_id": speaker.speaker_id, "field": "speaker_id"})
		speaker_ids[speaker.speaker_id] = true

	# Each unique instance once, so a shared conversation is not reported twice.
	for conversation in collected.conversations:
		report.merge(TalkValidator.validate_conversation(conversation, collected.speakers))

	# Content should reference resources its own node carries; anything else
	# still plays but is missing from the editor's dropdowns.
	if root != null:
		_check_collections(root, report)

	_report_id_collisions(collected, report)
	return report


## Reports conversation ids declared more than once: within the library,
## within one node, or across nodes.
static func _report_id_collisions(collected: Collected, report: TalkValidationReport) -> void:
	var by_id: Dictionary = {}
	for declaration in collected.declarations:
		if not by_id.has(declaration.id):
			by_id[declaration.id] = []
		by_id[declaration.id].append(declaration)

	for id in by_id:
		var declarations: Array = by_id[id]
		if declarations.size() < 2:
			continue

		var library_instances: Array = []
		var per_node: Dictionary = {}
		for declaration in declarations:
			if declaration.from_library:
				if not library_instances.has(declaration.conversation):
					library_instances.append(declaration.conversation)
			else:
				if not per_node.has(declaration.where):
					per_node[declaration.where] = []
				if not per_node[declaration.where].has(declaration.conversation):
					per_node[declaration.where].append(declaration.conversation)

		# The library is one namespace: two resources under one id is ambiguous.
		if library_instances.size() > 1:
			report.add(&"DUPLICATE_CONVERSATION_ID", &"error",
				"The library declares '%s' %d times." % [id, library_instances.size()],
				{"conversation_id": id, "field": "conversation_id"})

		# Within one node, the second copy can never be reached: find_conversation
		# returns the first match.
		for where in per_node:
			if per_node[where].size() > 1:
				report.add(&"DUPLICATE_CONVERSATION_ID", &"error",
					"'%s' declares '%s' %d times; only the first can ever play."
						% [where, id, per_node[where].size()],
					{"conversation_id": id, "field": "conversation_id"})

		# Normal across NPCs; only a problem if more than one is saved to the
		# library, so it is a warning.
		if per_node.size() > 1:
			report.add(&"SHARED_CONVERSATION_ID", &"warning",
				"'%s' is declared by %d nodes (%s). Ids are per node, so this is "
				% [id, per_node.size(), ", ".join(PackedStringArray(per_node.keys()))]
				+ "only a problem if more than one is promoted to the library.",
				{"conversation_id": id, "field": "conversation_id"})

		# A node id that matches a library id overrides the library for that
		# node (find_conversation checks the node first), so it is not reported.


static func _walk(node: Node, root: Node, out: Collected) -> void:
	if node is NPCTalkKit:
		var talkkit := node as NPCTalkKit
		var where := String(root.get_path_to(node))
		for speaker in talkkit.speakers:
			_collect_speaker(out, speaker)
		_collect_speaker(out, talkkit.quick_say_speaker)
		for conversation in talkkit.conversations:
			if conversation == null:
				continue
			_collect_speaker(out, conversation.default_speaker)
			for line in conversation.lines:
				if line != null:
					_collect_speaker(out, line.speaker)
		for conversation in talkkit.conversations:
			if conversation == null:
				continue
			if not out.conversations.has(conversation):
				out.conversations.append(conversation)
			_record(out, conversation, where, false)
	for child in node.get_children():
		_walk(child, root, out)


static func _record(
	out: Collected,
	conversation: TalkConversation,
	where: String,
	from_library: bool,
) -> void:
	var declaration := Declaration.new()
	declaration.id = conversation.conversation_id
	declaration.conversation = conversation
	declaration.where = where
	declaration.from_library = from_library
	out.declarations.append(declaration)


## Collects every speaker reachable from the node, including ones only a line
## references, so all of them are validated.
static func _collect_speaker(out: Collected, speaker: TalkSpeaker) -> void:
	if speaker != null and not out.speakers.has(speaker):
		out.speakers.append(speaker)


static func _check_collections(node: Node, report: TalkValidationReport) -> void:
	if node is NPCTalkKit:
		var talkkit := node as NPCTalkKit
		for conversation in talkkit.conversations:
			report.merge(TalkValidator.validate_against_collection(
				conversation, talkkit.speakers, talkkit.dialogue_boxes))
	for child in node.get_children():
		_check_collections(child, report)
