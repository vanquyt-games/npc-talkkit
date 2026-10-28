@tool
## Shows the effective value of a Quick Say slot, such as
## *Default: Screen · Bottom* when the placement slot is empty. Customize turns
## that default into an editable resource.
extends HBoxContainer

enum Kind { PLACEMENT }
enum { MENU_CUSTOMIZE }

var component: NPCTalkKit
var kind: Kind = Kind.PLACEMENT

var _summary: Label
var _menu: MenuButton


func _ready() -> void:
	add_theme_constant_override("separation", 4)

	_summary = Label.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_theme_font_size_override("font_size", 11)
	add_child(_summary)

	_menu = MenuButton.new()
	_menu.icon = _editor_icon("Duplicate")
	if _menu.icon == null:
		_menu.text = "⋮"
	_menu.tooltip_text = "Customize this placement"
	var popup := _menu.get_popup()
	popup.add_icon_item(_editor_icon("Duplicate"), "Customize", MENU_CUSTOMIZE)
	popup.id_pressed.connect(_on_menu)
	add_child(_menu)
	refresh()


## Editor icons exist only inside the editor; elsewhere this returns null and
## the control falls back to text.
func _editor_icon(icon_name: StringName) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme == null or not editor_theme.has_icon(icon_name, &"EditorIcons"):
		return null
	return editor_theme.get_icon(icon_name, &"EditorIcons")


func _on_menu(id: int) -> void:
	if id == MENU_CUSTOMIZE:
		_customize_placement()


func refresh() -> void:
	if _summary == null or _menu == null:
		return
	_menu.disabled = component == null
	var placed := component != null and component.quick_say_placement != null
	_summary.text = "" if placed else describe_placement(component)
	var popup := _menu.get_popup()
	popup.set_item_disabled(popup.get_item_index(MENU_CUSTOMIZE), placed)


#region Wording

static func describe_placement(node: NPCTalkKit) -> String:
	if node == null:
		return ""
	if node.quick_say_placement != null:
		return "Default: %s" % describe_anchor(node.quick_say_placement)
	return "Default: the box's own placement"


## Reads an anchor the way a person would describe it.
static func describe_anchor(anchor: TalkAnchor) -> String:
	if anchor == null:
		return "Screen · Bottom"
	if anchor.mode == TalkAnchor.Mode.NODE_FOLLOW:
		if anchor.follow_target.is_empty():
			return "Follows this NPC"
		return "Follows %s" % String(anchor.follow_target).get_file()
	if anchor.screen_spot == TalkAnchor.Spot.ABSOLUTE:
		return "Screen · %d, %d" % [anchor.screen_position.x, anchor.screen_position.y]
	return "Screen · %s" % _spot_name(anchor.screen_spot)


static func _spot_name(spot: TalkAnchor.Spot) -> String:
	match spot:
		TalkAnchor.Spot.TOP_LEFT: return "Top left"
		TalkAnchor.Spot.TOP: return "Top"
		TalkAnchor.Spot.TOP_RIGHT: return "Top right"
		TalkAnchor.Spot.LEFT: return "Left"
		TalkAnchor.Spot.CENTER: return "Centre"
		TalkAnchor.Spot.RIGHT: return "Right"
		TalkAnchor.Spot.BOTTOM_LEFT: return "Bottom left"
		TalkAnchor.Spot.BOTTOM: return "Bottom"
		TalkAnchor.Spot.BOTTOM_RIGHT: return "Bottom right"
	return "Bottom"

#endregion


func _customize_placement() -> void:
	if component == null or component.quick_say_placement != null:
		return
	component.quick_say_placement = TalkAnchor.new()
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()
		EditorInterface.edit_node(component)
	refresh()
