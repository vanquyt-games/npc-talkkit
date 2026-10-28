class_name TalkValidationIssue
extends RefCounted

var code: StringName
var severity: StringName
var speaker_id: StringName
var conversation_id: StringName
var line_id: StringName
var line_index := -1
var field := ""
var message := ""


static func create(
	issue_code: StringName,
	issue_severity: StringName,
	issue_message: String,
	context: Dictionary = {},
) -> TalkValidationIssue:
	var issue := TalkValidationIssue.new()
	issue.code = issue_code
	issue.severity = issue_severity
	issue.message = issue_message
	issue.speaker_id = StringName(context.get("speaker_id", ""))
	issue.conversation_id = StringName(context.get("conversation_id", ""))
	issue.line_id = StringName(context.get("line_id", ""))
	issue.line_index = int(context.get("line_index", -1))
	issue.field = str(context.get("field", ""))
	return issue


func to_dictionary() -> Dictionary:
	var data := {
		"code": str(code),
		"severity": str(severity),
		"field": field,
		"message": message,
	}
	if not speaker_id.is_empty():
		data["speaker_id"] = str(speaker_id)
	if not conversation_id.is_empty():
		data["conversation_id"] = str(conversation_id)
	if not line_id.is_empty():
		data["line_id"] = str(line_id)
	if line_index >= 0:
		data["line_index"] = line_index
	return data
