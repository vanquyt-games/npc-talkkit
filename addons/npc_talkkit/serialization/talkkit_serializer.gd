class_name TalkKitSerializer
extends RefCounted


static func speaker_to_dictionary(speaker: TalkSpeaker) -> Dictionary:
	var data := _speaker_fields(speaker)
	data["schema_version"] = TalkKitConstants.SCHEMA_VERSION
	return data


## The speaker's fields without the document header, for embedding.
static func _speaker_fields(speaker: TalkSpeaker) -> Dictionary:
	var variants: Dictionary = {}
	for name in speaker.variants:
		variants[str(name)] = visual_to_dictionary(speaker.variants[name])
	return {
		"speaker_id": str(speaker.speaker_id),
		"display_name": speaker.display_name,
		"visual": visual_to_dictionary(speaker.visual),
		"variants": variants,
		"voice_enabled": speaker.voice_enabled,
		"voice_blip": _resource_path(speaker.voice_blip),
		"voice_pitch_min": speaker.voice_pitch_min,
		"voice_pitch_max": speaker.voice_pitch_max,
		"voice_blip_interval": speaker.voice_blip_interval,
	}


## Writes the dialogue visual inline rather than as a resource path, so the
## JSON is usable outside this project.
static func visual_to_dictionary(visual: TalkDialogueVisual) -> Variant:
	if visual == null:
		return null
	return {
		"texture": _resource_path(visual.texture),
		"sprite_frames": _resource_path(visual.sprite_frames),
		"animation": str(visual.animation),
		"flip_h": visual.flip_h,
	}


static func visual_from_dictionary(data: Variant) -> TalkDialogueVisual:
	if not data is Dictionary:
		return null
	var visual := TalkDialogueVisual.new()
	visual.texture = _load_typed_resource(str(data.get("texture", "")), "Texture2D") as Texture2D
	visual.sprite_frames = _load_typed_resource(str(data.get("sprite_frames", "")), "SpriteFrames") as SpriteFrames
	visual.animation = StringName(data.get("animation", "default"))
	visual.flip_h = bool(data.get("flip_h", false))
	return visual


## Local keys for speakers without an id. A speaker with an id is written as
## that id; one without is embedded in the conversation under a local key and
## rebuilt on import.
static func _local_speakers(conversation: TalkConversation) -> Dictionary:
	var keys: Dictionary = {}
	for speaker in _speakers_used(conversation):
		if speaker.speaker_id.is_empty():
			keys[speaker] = "#%d" % keys.size()
	return keys


## Every speaker the conversation uses, in a fixed order so repeated exports
## produce identical output.
static func _speakers_used(conversation: TalkConversation) -> Array[TalkSpeaker]:
	var found: Array[TalkSpeaker] = []
	if conversation.default_speaker != null:
		found.append(conversation.default_speaker)
	for line in conversation.lines:
		if line == null or line.speaker_mode != TalkLine.SpeakerMode.SPEAKER:
			continue
		if line.speaker != null and not found.has(line.speaker):
			found.append(line.speaker)
	return found


static func conversation_to_dictionary(conversation: TalkConversation) -> Dictionary:
	var local := _local_speakers(conversation)
	var serialized_lines: Array[Dictionary] = []
	for line in conversation.lines:
		if line != null:
			serialized_lines.append(line_to_dictionary(line, local))
	var embedded: Dictionary = {}
	for speaker in local:
		embedded[local[speaker]] = _speaker_fields(speaker)
	return {
		"schema_version": TalkKitConstants.SCHEMA_VERSION,
		"conversation_id": str(conversation.conversation_id),
		"default_speaker": _speaker_key(conversation.default_speaker, local),
		"speakers": embedded,
		"default_dialogue_box": _resource_path(conversation.default_dialogue_box),
		"default_placement": _resource_path(conversation.default_placement),
		"event_id": str(conversation.event_id) if not conversation.event_id.is_empty() else null,
		"event_payload": _json_safe(conversation.event_payload),
		"lines": serialized_lines,
	}


const _SPEAKER_MODES := ["inherit", "none", "speaker"]


static func _line_speaker_key(line: TalkLine, local: Dictionary) -> String:
	if line.speaker_mode != TalkLine.SpeakerMode.SPEAKER:
		return ""
	return _speaker_key(line.speaker, local) if line.speaker != null else str(line.speaker_id)


static func line_to_dictionary(line: TalkLine, local: Dictionary = {}) -> Dictionary:
	return {
		"line_id": str(line.line_id),
		"speaker_mode": _SPEAKER_MODES[line.speaker_mode],
		# Written only when speaker_mode is SPEAKER, so a leftover reference on
		# an inheriting line does not come back on import.
		"speaker": _line_speaker_key(line, local),
		"display_name_override": line.display_name_override,
		"visual_variant": str(line.visual_variant),
		"text": line.text,
		"characters_per_second": line.characters_per_second,
		"voice_clip": _resource_path(line.voice_clip),
		"dialogue_box": _resource_path(line.dialogue_box),
		"placement": _resource_path(line.placement),
		"event_id": str(line.event_id) if not line.event_id.is_empty() else null,
		"event_payload": _json_safe(line.event_payload),
		"event_blocking": line.event_blocking,
	}


static func export_speaker_json(speaker: TalkSpeaker) -> String:
	return JSON.stringify(speaker_to_dictionary(speaker), "  ", true, true)


static func export_conversation_json(conversation: TalkConversation) -> String:
	return JSON.stringify(conversation_to_dictionary(conversation), "  ", true, true)


static func parse_speaker_json(json_text: String) -> TalkValidationReport:
	var parsed := _parse_json(json_text)
	if not parsed.is_valid():
		return parsed
	var data: Dictionary = parsed.value
	if not _check_schema(data, parsed):
		return parsed
	var context := {"speaker_id": data.get("speaker_id", "")}
	var visual: Variant = data.get("visual")
	if visual is Dictionary:
		_validate_json_resource_path(visual.get("texture"), "visual", parsed, context)
		_validate_json_resource_path(visual.get("sprite_frames"), "visual", parsed, context)
	_validate_json_resource_path(data.get("voice_blip"), "voice_blip", parsed, context)
	if not parsed.is_valid():
		return parsed
	parsed.value = speaker_from_dictionary(data)
	parsed.merge(TalkValidator.validate_speaker(parsed.value, true))
	parsed.intended_changes.append({"operation": "upsert_speaker", "speaker_id": str(parsed.value.speaker_id)})
	return parsed


static func parse_conversation_json(json_text: String, speakers: Array[TalkSpeaker] = []) -> TalkValidationReport:
	var parsed := _parse_json(json_text)
	if not parsed.is_valid():
		return parsed
	var data: Dictionary = parsed.value
	if not _check_schema(data, parsed):
		return parsed
	var raw_lines: Variant = data.get("lines", [])
	if raw_lines is Array:
		for raw_line in raw_lines:
			if raw_line is Dictionary:
				_validate_json_resource_path(raw_line.get("voice_clip"), "voice_clip", parsed, {
					"conversation_id": data.get("conversation_id", ""),
					"line_id": raw_line.get("line_id", ""),
				})
	if not parsed.is_valid():
		return parsed
	parsed.value = conversation_from_dictionary(data, speakers)
	parsed.merge(TalkValidator.validate_conversation(parsed.value, speakers))
	parsed.intended_changes.append({"operation": "upsert_conversation", "conversation_id": str(parsed.value.conversation_id)})
	return parsed


static func speaker_from_dictionary(data: Dictionary) -> TalkSpeaker:
	var speaker := TalkSpeaker.new()
	speaker.speaker_id = StringName(data.get("speaker_id", ""))
	speaker.display_name = str(data.get("display_name", ""))
	speaker.visual = visual_from_dictionary(data.get("visual"))
	var variants: Variant = data.get("variants", {})
	if variants is Dictionary:
		for name in variants:
			var variant := visual_from_dictionary(variants[name])
			if variant != null:
				speaker.variants[StringName(name)] = variant
	speaker.voice_enabled = bool(data.get("voice_enabled", true))
	speaker.voice_blip = _load_typed_resource(str(data.get("voice_blip", "")), "AudioStream") as AudioStream
	speaker.voice_pitch_min = float(data.get("voice_pitch_min", 0.95))
	speaker.voice_pitch_max = float(data.get("voice_pitch_max", 1.05))
	speaker.voice_blip_interval = float(data.get("voice_blip_interval", 0.04))
	return speaker


## [param speakers] resolves speaker ids to resources. Without it the
## conversation still parses and keeps the ids on each line, but
## default_speaker stays empty.
static func conversation_from_dictionary(data: Dictionary, speakers: Array[TalkSpeaker] = []) -> TalkConversation:
	var conversation := TalkConversation.new()
	conversation.conversation_id = StringName(data.get("conversation_id", ""))
	# Built once per conversation, so lines sharing an embedded speaker share
	# one resource.
	var local: Dictionary = {}
	var embedded: Variant = data.get("speakers", {})
	if embedded is Dictionary:
		for key in embedded:
			local[str(key)] = speaker_from_dictionary(embedded[key])
	conversation.default_speaker = _resolve_speaker(
		str(data.get("default_speaker", "")), speakers, local)
	conversation.default_dialogue_box = _load_template(str(data.get("default_dialogue_box", "")))
	conversation.default_placement = _load_anchor(str(data.get("default_placement", "")))
	conversation.event_id = StringName(data.get("event_id", "") if data.get("event_id") != null else "")
	conversation.event_payload = data.get("event_payload")
	var raw_lines: Variant = data.get("lines", [])
	if raw_lines is Array:
		for raw_line in raw_lines:
			if raw_line is Dictionary:
				conversation.lines.append(line_from_dictionary(raw_line, speakers, local))
	return conversation


static func line_from_dictionary(
	data: Dictionary, speakers: Array[TalkSpeaker] = [], local: Dictionary = {},
) -> TalkLine:
	var line := TalkLine.new()
	line.line_id = StringName(data.get("line_id", ""))
	# "speaker" holds a library id or a local key of an embedded speaker. A
	# library id is also kept on the line so it round-trips; a local key is not.
	var mode := _SPEAKER_MODES.find(str(data.get("speaker_mode", "inherit")))
	line.speaker_mode = (mode if mode >= 0 else TalkLine.SpeakerMode.INHERIT) as TalkLine.SpeakerMode
	var key := str(data.get("speaker", ""))
	line.speaker = _resolve_speaker(key, speakers, local)
	line.speaker_id = StringName("" if key.begins_with("#") else key)
	# A line that names a speaker without a speaker_mode is treated as SPEAKER.
	if line.speaker_mode == TalkLine.SpeakerMode.INHERIT and not key.is_empty():
		line.speaker_mode = TalkLine.SpeakerMode.SPEAKER
	line.display_name_override = str(data.get("display_name_override", ""))
	line.visual_variant = StringName(data.get("visual_variant", ""))
	line.text = str(data.get("text", ""))
	line.characters_per_second = float(data.get("characters_per_second", 0.0))
	line.voice_clip = _load_typed_resource(str(data.get("voice_clip", "")), "AudioStream") as AudioStream
	line.dialogue_box = _load_template(str(data.get("dialogue_box", "")))
	line.placement = _load_anchor(str(data.get("placement", "")))
	line.event_id = StringName(data.get("event_id", "") if data.get("event_id") != null else "")
	line.event_payload = data.get("event_payload")
	line.event_blocking = bool(data.get("event_blocking", false))
	return line


static func _parse_json(json_text: String) -> TalkValidationReport:
	var report := TalkValidationReport.new()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		report.add(&"MALFORMED_JSON", &"error", "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return report
	if not json.data is Dictionary:
		report.add(&"INVALID_JSON_ROOT", &"error", "JSON root must be an object.")
		return report
	report.value = json.data
	return report


static func _check_schema(data: Dictionary, report: TalkValidationReport) -> bool:
	var version := str(data.get("schema_version", ""))
	if version != TalkKitConstants.SCHEMA_VERSION:
		report.add(&"UNSUPPORTED_SCHEMA_VERSION", &"error", "Expected schema version %s, got '%s'." % [TalkKitConstants.SCHEMA_VERSION, version], {"field": "schema_version"})
		return false
	return true


static func _resource_path(resource: Resource) -> Variant:
	return null if resource == null or resource.resource_path.is_empty() else resource.resource_path


static func _validate_json_resource_path(value: Variant, field: String, report: TalkValidationReport, context: Dictionary) -> void:
	if value == null or str(value).is_empty():
		return
	var path := str(value)
	if not path.begins_with("res://"):
		report.add(&"INVALID_RESOURCE_PATH", &"error", "Resource path must begin with res://.", context.merged({"field": field}))
	elif not ResourceLoader.exists(path):
		report.add(&"MISSING_RESOURCE", &"error", "Resource '%s' does not exist." % path, context.merged({"field": field}))


## Loads a TalkBoxTemplate; the cast does the type check, since is_class()
## does not see GDScript class names.
static func _load_template(path: String) -> TalkBoxTemplate:
	if path.is_empty() or not path.begins_with("res://") or not ResourceLoader.exists(path):
		return null
	return load(path) as TalkBoxTemplate


## How a speaker is named in JSON: its id, or else the local key of its
## embedded copy. Local keys start with "#", which is not valid in an id.
static func _speaker_key(speaker: TalkSpeaker, local: Dictionary = {}) -> String:
	if speaker == null:
		return ""
	if not speaker.speaker_id.is_empty():
		return str(speaker.speaker_id)
	return str(local.get(speaker, ""))


## Loads a TalkAnchor; the cast does the type check.
static func _load_anchor(path: String) -> TalkAnchor:
	if path.is_empty() or not path.begins_with("res://") or not ResourceLoader.exists(path):
		return null
	return load(path) as TalkAnchor


## Resolves a "speaker" value: a key starting with "#" is local, anything else
## is a library id.
static func _resolve_speaker(
	key: String, speakers: Array[TalkSpeaker], local: Dictionary,
) -> TalkSpeaker:
	if key.is_empty():
		return null
	if key.begins_with("#"):
		return local.get(key)
	return _find_speaker(StringName(key), speakers)


static func _find_speaker(speaker_id: StringName, speakers: Array[TalkSpeaker]) -> TalkSpeaker:
	if speaker_id.is_empty():
		return null
	for speaker in speakers:
		if speaker != null and speaker.speaker_id == speaker_id:
			return speaker
	return null


static func _load_typed_resource(path: String, expected_class: String) -> Resource:
	if path.is_empty() or not path.begins_with("res://") or not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	return resource if resource != null and resource.is_class(expected_class) else null


static func _json_safe(value: Variant) -> Variant:
	if value == null or value is bool or value is int or value is float or value is String:
		return value
	if value is StringName:
		return str(value)
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return _json_safe(item))
	if value is Dictionary:
		var output := {}
		for key in value:
			output[str(key)] = _json_safe(value[key])
		return output
	return str(value)
