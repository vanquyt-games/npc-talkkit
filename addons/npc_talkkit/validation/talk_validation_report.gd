class_name TalkValidationReport
extends RefCounted

var issues: Array[TalkValidationIssue] = []
var intended_changes: Array[Dictionary] = []
var value: Variant


func add_issue(issue: TalkValidationIssue) -> void:
	issues.append(issue)


func add(
	code: StringName,
	severity: StringName,
	message: String,
	context: Dictionary = {},
) -> void:
	add_issue(TalkValidationIssue.create(code, severity, message, context))


func merge(other: TalkValidationReport) -> void:
	if other == null:
		return
	issues.append_array(other.issues)
	intended_changes.append_array(other.intended_changes)


func error_count() -> int:
	return issues.filter(func(issue: TalkValidationIssue) -> bool: return issue.severity == &"error").size()


func warning_count() -> int:
	return issues.filter(func(issue: TalkValidationIssue) -> bool: return issue.severity == &"warning").size()


func is_valid() -> bool:
	return error_count() == 0


func to_dictionary(include_issues := true) -> Dictionary:
	var data := {
		"schema_version": TalkKitConstants.SCHEMA_VERSION,
		"status": "valid" if is_valid() else "issues_found",
		"summary": {
			"errors": error_count(),
			"warnings": warning_count(),
			"total": issues.size(),
		},
	}
	if not intended_changes.is_empty():
		data["intended_changes"] = intended_changes.duplicate(true)
	if include_issues:
		data["issues"] = issues.map(func(issue: TalkValidationIssue) -> Dictionary: return issue.to_dictionary())
	return data

