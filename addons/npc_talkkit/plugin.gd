@tool
extends EditorPlugin

const InspectorPlugin := preload("res://addons/npc_talkkit/editor/talkkit_inspector_plugin.gd")
const Workspace := preload("res://addons/npc_talkkit/editor/talkkit_workspace.gd")
const ResourceManager := preload("res://addons/npc_talkkit/editor/talkkit_resource_manager.gd")
# One colour, like the editor's own main-screen icons; the node keeps the logo.
const ICON := preload("res://addons/npc_talkkit/icons/npc_talkkit_main_screen.svg")

var _inspector: EditorInspectorPlugin
var _workspace: Control


func _enter_tree() -> void:
	ResourceManager.register_preset_setting()
	_workspace = Workspace.new()
	_workspace.plugin = self
	EditorInterface.get_editor_main_screen().add_child(_workspace)
	_make_visible(false)

	_inspector = InspectorPlugin.new()
	_inspector.plugin = self
	_inspector.workspace = _workspace
	add_inspector_plugin(_inspector)

	var selection := EditorInterface.get_selection()
	if selection != null and not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)
	_sync_with_selection()


func _exit_tree() -> void:
	var selection := EditorInterface.get_selection()
	if selection != null and selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	if _workspace != null:
		_workspace.queue_free()
	_workspace = null
	if _inspector != null:
		remove_inspector_plugin(_inspector)
	_inspector = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _workspace != null:
		_workspace.visible = visible
		if visible:
			_workspace.refresh_contexts()
			_workspace.refresh()


func _get_plugin_name() -> String:
	return "TalkKit"


func _get_plugin_icon() -> Texture2D:
	return ICON


## Shows the TalkKit workspace for [param component], opened at [param section]
## and, when given, focused on [param resource].
func open_workspace(
	component: NPCTalkKit,
	section := "conversations",
	resource: Resource = null,
) -> void:
	if _workspace == null:
		return
	_workspace.set_component(component)
	_workspace.open_section(section, resource)
	EditorInterface.set_main_screen_editor(_get_plugin_name())


func _on_selection_changed() -> void:
	_sync_with_selection()


func _sync_with_selection() -> void:
	if _workspace == null:
		return
	var selected: Array[Node] = []
	for node in EditorInterface.get_selection().get_selected_nodes():
		selected.append(node)
	_workspace.observe_scene_selection(selected)
