@tool
## A 3×3 picker for a layer's Position: corners, edges, and Fill in the
## middle. The chosen cell is filled with the accent colour; a cell that
## already holds layers on the same slot carries an outline.
extends HBoxContainer

signal position_chosen(spot: TalkBoxLayer.Position)

const GRID := [
	TalkBoxLayer.Position.TOP_LEFT, TalkBoxLayer.Position.TOP, TalkBoxLayer.Position.TOP_RIGHT,
	TalkBoxLayer.Position.LEFT, TalkBoxLayer.Position.FILL, TalkBoxLayer.Position.RIGHT,
	TalkBoxLayer.Position.BOTTOM_LEFT, TalkBoxLayer.Position.BOTTOM, TalkBoxLayer.Position.BOTTOM_RIGHT,
]
const ARROWS := ["↖", "↑", "↗", "←", "■", "→", "↙", "↓", "↘"]
const ACCENT := Color(0.34, 0.6, 0.95)
const TAKEN := Color(0.35, 0.72, 1.0)

var _buttons: Array[Button] = []
var _label: Label
var _chosen: TalkBoxLayer.Position = TalkBoxLayer.Position.FILL
var _taken: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 10)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	for index in GRID.size():
		var button := Button.new()
		button.text = ARROWS[index]
		button.custom_minimum_size = Vector2(28, 24)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = TalkBoxLayer.POSITION_NAMES[GRID[index]]
		button.pressed.connect(func() -> void:
			set_chosen(GRID[index])
			position_chosen.emit(GRID[index]))
		grid.add_child(button)
		_buttons.append(button)
	_label = Label.new()
	add_child(_label)
	_restyle()


## Marks [param spot] as the chosen cell.
func set_chosen(spot: TalkBoxLayer.Position) -> void:
	_chosen = spot
	_restyle()


func chosen() -> TalkBoxLayer.Position:
	return _chosen


## Outlines the cells that already hold layers.
func set_taken(spots: Array) -> void:
	_taken = spots
	_restyle()


func _restyle() -> void:
	_label.text = TalkBoxLayer.POSITION_NAMES[_chosen]
	for index in _buttons.size():
		var button := _buttons[index]
		var spot: TalkBoxLayer.Position = GRID[index]
		var selected := spot == _chosen
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(3)
		style.bg_color = ACCENT if selected else Color(1, 1, 1, 0.06)
		if _taken.has(spot) and not selected:
			style.border_color = TAKEN
			style.set_border_width_all(1)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = ACCENT.lightened(0.15) if selected else Color(1, 1, 1, 0.14)
		for state in ["normal", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		for state in ["hover", "hover_pressed"]:
			button.add_theme_stylebox_override(state, hover)
		var text_color := Color.WHITE if selected else Color(1, 1, 1, 0.7)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, text_color)
