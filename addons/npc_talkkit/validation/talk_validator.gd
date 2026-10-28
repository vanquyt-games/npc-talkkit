class_name TalkValidator
extends RefCounted


## [param require_id] is true for a speaker filed in a library, where other
## content refers to it by id. A speaker referenced directly needs no id.
static func validate_speaker(speaker: TalkSpeaker, require_id := false) -> TalkValidationReport:
	var report := TalkValidationReport.new()
	if speaker == null:
		report.add(&"MISSING_SPEAKER", &"error", "Speaker is null.")
		return report
	var context := {"speaker_id": speaker.speaker_id}
	if require_id or not speaker.speaker_id.is_empty():
		_validate_id(speaker.speaker_id, "speaker_id", report, context)
	if speaker.display_name.strip_edges().is_empty():
		report.add(&"EMPTY_DISPLAY_NAME", &"warning", "Speaker display name is empty.", context.merged({"field": "display_name"}))
	_validate_visual(speaker.visual, "visual", report, context)
	for variant in speaker.variants:
		_validate_visual(speaker.variants[variant], "variants/%s" % variant, report, context)
	_validate_resource(speaker.voice_blip, "voice_blip", report, context)
	return report


## Reports a visual that is set but holds nothing. A missing visual is valid.
static func _validate_visual(visual: TalkDialogueVisual, field: String, report: TalkValidationReport, context: Dictionary) -> void:
	if visual == null:
		return
	if visual.is_empty():
		report.add(&"EMPTY_DIALOGUE_VISUAL", &"warning",
			"Dialogue visual has neither a texture nor sprite frames.",
			context.merged({"field": field}))
		return
	_validate_resource(visual.texture, field, report, context)
	_validate_resource(visual.sprite_frames, field, report, context)
	if visual.texture == null and visual.sprite_frames != null and not visual.sprite_frames.has_animation(visual.animation):
		report.add(&"MISSING_VISUAL_ANIMATION", &"warning",
			"Sprite frames have no animation '%s'." % visual.animation,
			context.merged({"field": field}))


static func validate_conversation(
	conversation: TalkConversation,
	speakers: Array[TalkSpeaker] = [],
) -> TalkValidationReport:
	var report := TalkValidationReport.new()
	if conversation == null:
		report.add(&"MISSING_CONVERSATION", &"error", "Conversation is null.")
		return report
	var base := {"conversation_id": conversation.conversation_id}
	_validate_id(conversation.conversation_id, "conversation_id", report, base)
	if conversation.lines.is_empty():
		report.add(&"EMPTY_CONVERSATION", &"error", "Conversation has no lines.", base.merged({"field": "lines"}))
	var known_speakers: Dictionary = {}
	for entry in speakers:
		if entry != null:
			known_speakers[entry.speaker_id] = true
	# The runtime falls back to the Classic Panel, but a missing box is still
	# reported so the fallback is not relied on.
	if conversation.default_dialogue_box == null and not _every_line_names_a_box(conversation):
		report.add(&"MISSING_DIALOGUE_BOX", &"warning",
			"Conversation has no default dialogue box.",
			base.merged({"field": "default_dialogue_box"}))
	var line_ids: Dictionary = {}
	for index in conversation.lines.size():
		var line := conversation.lines[index]
		if line == null:
			report.add(&"NULL_LINE", &"error", "Line %d is null." % index, base.merged({"field": "lines"}))
			continue
		var context := base.merged({"line_id": line.line_id, "line_index": index})
		if not line.line_id.is_empty():
			_validate_id(line.line_id, "line_id", report, context)
			if line_ids.has(line.line_id):
				report.add(&"DUPLICATE_LINE_ID", &"error", "Duplicate line id '%s'." % line.line_id, context.merged({"field": "line_id"}))
			line_ids[line.line_id] = true
		if line.text.strip_edges().is_empty():
			report.add(&"EMPTY_DIALOGUE_LINE", &"error", "Dialogue line text is empty.", context.merged({"field": "text"}))
		# No speaker is valid (a narrator); SPEAKER mode with no speaker is not.
		if line.speaker_mode == TalkLine.SpeakerMode.SPEAKER:
			if line.speaker == null and line.speaker_id.is_empty():
				report.add(&"MISSING_SPEAKER_REFERENCE", &"error",
					"Line names a speaker but points at none.",
					context.merged({"field": "speaker"}))
			elif line.speaker == null and not speakers.is_empty() and not known_speakers.has(line.speaker_id):
				report.add(&"UNKNOWN_SPEAKER", &"error",
					"Speaker id '%s' does not exist." % line.speaker_id,
					context.merged({"field": "speaker_id"}))
		_validate_resource(line.placement, "placement", report, context)
		if not line.event_id.is_empty():
			_validate_id(line.event_id, "event_id", report, context)
		_validate_resource(line.voice_clip, "voice_clip", report, context)
		_validate_resource(line.dialogue_box, "dialogue_box", report, context)
	return report


## A conversation needs no default box when every line brings its own.
static func _every_line_names_a_box(conversation: TalkConversation) -> bool:
	if conversation.lines.is_empty():
		return false
	for line in conversation.lines:
		if line == null or line.dialogue_box == null:
			return false
	return true


## Reports speakers and boxes a conversation uses that are not in the node's
## collections. They still play, but do not appear in the editor dropdowns.
static func validate_against_collection(
	conversation: TalkConversation,
	available_speakers: Array[TalkSpeaker],
	available_boxes: Array[TalkBoxTemplate],
) -> TalkValidationReport:
	var report := TalkValidationReport.new()
	if conversation == null:
		return report
	var base := {"conversation_id": conversation.conversation_id}
	if conversation.default_speaker != null and not available_speakers.has(conversation.default_speaker):
		report.add(&"SPEAKER_NOT_IN_COLLECTION", &"warning",
			"Default speaker is not one of this node's speakers.",
			base.merged({"field": "default_speaker"}))
	if conversation.default_dialogue_box != null and not available_boxes.has(conversation.default_dialogue_box):
		report.add(&"BOX_NOT_IN_COLLECTION", &"warning",
			"Default dialogue box is not one of this node's boxes.",
			base.merged({"field": "default_dialogue_box"}))
	for index in conversation.lines.size():
		var line := conversation.lines[index]
		if line == null:
			continue
		var context := base.merged({"line_id": line.line_id, "line_index": index})
		if line.speaker != null and not available_speakers.has(line.speaker):
			report.add(&"SPEAKER_NOT_IN_COLLECTION", &"warning",
				"A line names a speaker that is not one of this node's speakers.",
				context.merged({"field": "speaker"}))
		if line.dialogue_box != null and not available_boxes.has(line.dialogue_box):
			report.add(&"BOX_NOT_IN_COLLECTION", &"warning",
				"A line names a dialogue box that is not one of this node's boxes.",
				context.merged({"field": "dialogue_box"}))
	return report


## Checks that a scene implements the dialogue box renderer contract.
static func validate_renderer(scene: PackedScene) -> TalkValidationReport:
	var report := TalkValidationReport.new()
	if scene == null:
		report.add(&"MISSING_RENDERER", &"error",
			"A renderer scene is required.", {"field": "renderer"})
		return report
	var instance := scene.instantiate()
	for method in ["setup", "show_line", "finish_line", "close"]:
		if not instance.has_method(method):
			report.add(&"INVALID_RENDERER", &"error",
				"Renderer is missing method '%s'." % method,
				{"field": "renderer"})
	instance.free()
	return report


static func validate_all(
	speakers: Array[TalkSpeaker],
	conversations: Array[TalkConversation],
) -> TalkValidationReport:
	var report := TalkValidationReport.new()
	# Every entry in a library needs a unique id.
	var speaker_ids: Dictionary = {}
	for entry in speakers:
		report.merge(validate_speaker(entry, true))
		if entry == null:
			continue
		if speaker_ids.has(entry.speaker_id):
			report.add(&"DUPLICATE_SPEAKER_ID", &"error", "Duplicate speaker id '%s'." % entry.speaker_id, {"speaker_id": entry.speaker_id, "field": "speaker_id"})
		speaker_ids[entry.speaker_id] = true
	var conversation_ids: Dictionary = {}
	for conversation in conversations:
		report.merge(validate_conversation(conversation, speakers))
		if conversation == null:
			continue
		if conversation_ids.has(conversation.conversation_id):
			report.add(&"DUPLICATE_CONVERSATION_ID", &"error", "Duplicate conversation id '%s'." % conversation.conversation_id, {"conversation_id": conversation.conversation_id, "field": "conversation_id"})
		conversation_ids[conversation.conversation_id] = true
	return report


static func _validate_id(id: StringName, field: String, report: TalkValidationReport, context: Dictionary) -> void:
	var text := str(id)
	if text.is_empty():
		report.add(&"MISSING_STABLE_ID", &"error", "%s is required." % field, context.merged({"field": field}))
		return
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_.-]+$")
	if regex.search(text) == null:
		report.add(&"INVALID_STABLE_ID", &"error", "%s contains unsupported characters." % field, context.merged({"field": field}))


static func _validate_resource(resource: Resource, field: String, report: TalkValidationReport, context: Dictionary) -> void:
	if resource == null or resource.resource_path.is_empty():
		return
	if not ResourceLoader.exists(resource.resource_path):
		report.add(&"MISSING_RESOURCE", &"warning", "Resource '%s' does not exist." % resource.resource_path, context.merged({"field": field}))
