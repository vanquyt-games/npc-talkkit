@tool
class_name TalkKitDatabase
extends Resource

@export var speakers: Array[TalkSpeaker] = []
@export var conversations: Array[TalkConversation] = []


func list_speakers() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in speakers:
		if entry != null:
			ids.append(entry.speaker_id)
	return ids


func get_speaker(speaker_id: StringName) -> TalkSpeaker:
	for entry in speakers:
		if entry != null and entry.speaker_id == speaker_id:
			return entry
	return null


func upsert_speaker(entry: TalkSpeaker, overwrite := false) -> bool:
	var report := TalkValidator.validate_speaker(entry, true)
	if not report.is_valid():
		return false
	var existing := get_speaker(entry.speaker_id)
	if existing != null and not overwrite:
		return false
	if existing == null:
		speakers.append(entry)
	else:
		for index in speakers.size():
			if speakers[index] == existing:
				speakers[index] = entry
				break
	emit_changed()
	return true


func list_conversations() -> Array[StringName]:
	var ids: Array[StringName] = []
	for conversation in conversations:
		if conversation != null:
			ids.append(conversation.conversation_id)
	return ids


func get_conversation(conversation_id: StringName) -> TalkConversation:
	for conversation in conversations:
		if conversation != null and conversation.conversation_id == conversation_id:
			return conversation
	return null


func create_conversation(data: Dictionary) -> TalkConversation:
	var conversation := TalkKitSerializer.conversation_from_dictionary(data)
	if get_conversation(conversation.conversation_id) != null:
		return null
	var report := TalkValidator.validate_conversation(conversation, speakers)
	if not report.is_valid():
		return null
	conversations.append(conversation)
	emit_changed()
	return conversation


func update_conversation(conversation_id: StringName, data: Dictionary) -> bool:
	var replacement := TalkKitSerializer.conversation_from_dictionary(data)
	if replacement.conversation_id != conversation_id:
		return false
	var report := TalkValidator.validate_conversation(replacement, speakers)
	if not report.is_valid():
		return false
	for index in conversations.size():
		if conversations[index] != null and conversations[index].conversation_id == conversation_id:
			conversations[index] = replacement
			emit_changed()
			return true
	return false


func delete_conversation(conversation_id: StringName) -> bool:
	for index in conversations.size():
		if conversations[index] != null and conversations[index].conversation_id == conversation_id:
			conversations.remove_at(index)
			emit_changed()
			return true
	return false


func validate_speaker(speaker_id: StringName) -> TalkValidationReport:
	return TalkValidator.validate_speaker(get_speaker(speaker_id), true)


func validate_conversation(conversation_id: StringName) -> TalkValidationReport:
	return TalkValidator.validate_conversation(get_conversation(conversation_id), speakers)


func validate_renderer(scene: PackedScene) -> TalkValidationReport:
	return TalkValidator.validate_renderer(scene)


func validate_all() -> TalkValidationReport:
	return TalkValidator.validate_all(speakers, conversations)


func export_conversation_json(conversation_id: StringName) -> String:
	var conversation := get_conversation(conversation_id)
	return "" if conversation == null else TalkKitSerializer.export_conversation_json(conversation)


func export_speaker_json(speaker_id: StringName) -> String:
	var entry := get_speaker(speaker_id)
	return "" if entry == null else TalkKitSerializer.export_speaker_json(entry)


func import_conversation_json(json_text: String, mode := "safe") -> TalkValidationReport:
	var report := TalkKitSerializer.parse_conversation_json(json_text, speakers)
	if not report.is_valid() or mode == "preview":
		return report
	var incoming := report.value as TalkConversation
	var existing := get_conversation(incoming.conversation_id)
	if existing != null and mode != "overwrite":
		report.add(&"OVERWRITE_REQUIRES_EXPLICIT_MODE", &"error", "Conversation already exists; use overwrite mode.", {"conversation_id": incoming.conversation_id})
		return report
	if existing == null:
		conversations.append(incoming)
	else:
		for index in conversations.size():
			if conversations[index] == existing:
				conversations[index] = incoming
				break
	emit_changed()
	return report


func import_speaker_json(json_text: String, mode := "safe") -> TalkValidationReport:
	var report := TalkKitSerializer.parse_speaker_json(json_text)
	if not report.is_valid() or mode == "preview":
		return report
	var incoming := report.value as TalkSpeaker
	var existing := get_speaker(incoming.speaker_id)
	if existing != null and mode != "overwrite":
		report.add(&"OVERWRITE_REQUIRES_EXPLICIT_MODE", &"error", "Speaker already exists; use overwrite mode.", {"speaker_id": incoming.speaker_id})
		return report
	upsert_speaker(incoming, existing != null)
	return report
