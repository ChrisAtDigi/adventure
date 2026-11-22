class_name KeypadPanel
extends Control
## Close-up of the lift's nine stone buttons. They are marked in the cave's own
## numerals, and they are not laid out in order.

signal solved

## Which number each button stands for, reading left to right, top to bottom.
const ORDER := [7, 2, 9, 4, 6, 1, 3, 8, 5]
## Incubation days for bays one, two and three (see the Hatchery).
const CODE := [6, 4, 8]
const WRONG := [
	"The buttons grind back out. Wrong. The lift has standards.",
	"Nothing. Somewhere far below, something sighs.",
	"Wrong again. The cave is not angry. The cave is taking notes.",
]
const STONE := Color(0.36, 0.35, 0.4)
const GLOW := Color(0.45, 0.95, 0.8)

## Set by GameUI before the panel is shown.
var ui: GameUI

var _entered: Array[int] = []
var _slots: Array[Control] = []
var _wrong := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.style(STONE, Color(0.2, 0.19, 0.24), 6, 14, 22))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -348
	panel.offset_bottom = 152
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var display := HBoxContainer.new()
	display.alignment = BoxContainer.ALIGNMENT_CENTER
	display.add_theme_constant_override("separation", 10)
	column.add_child(display)
	for i in CODE.size():
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(84, 70)
		slot.draw.connect(_draw_slot.bind(slot, i))
		display.add_child(slot)
		_slots.append(slot)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for number in ORDER:
		var key := Button.new()
		key.custom_minimum_size = Vector2(112, 96)
		key.focus_mode = Control.FOCUS_NONE
		key.add_theme_stylebox_override("normal", Kit.style(Color(0.46, 0.45, 0.5), Color(0.25, 0.24, 0.3), 3, 12, 4))
		key.add_theme_stylebox_override("hover", Kit.style(Color(0.54, 0.53, 0.58), GLOW, 3, 12, 4))
		key.add_theme_stylebox_override("pressed", Kit.style(Color(0.3, 0.3, 0.34), GLOW, 3, 12, 4))
		key.pressed.connect(press.bind(number))
		var face := Control.new()
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(_draw_key.bind(face, number))
		key.add_child(face)
		grid.add_child(key)

	var back := Kit.button("Step away")
	back.pressed.connect(func() -> void: ui.close_modal())
	column.add_child(back)


## Press the button that stands for `number`.
func press(number: int) -> void:
	if _entered.size() >= CODE.size():
		return
	Sfx.play("thunk", -8.0)
	_entered.append(number)
	_redraw()
	if _entered.size() < CODE.size():
		return
	var correct := true
	for i in CODE.size():
		correct = correct and _entered[i] == CODE[i]
	if correct:
		Sfx.play("power")
		Game.set_flag("lift_open")
		Game.award("counted")
		Game.say([
			"The third button sinks home. Deep in the rock, something very large and very old agrees with you.",
			"The lift doors open.",
		])
		solved.emit()
	else:
		Sfx.play("error")
		Game.say(WRONG[_wrong % WRONG.size()])
		_wrong += 1
		await get_tree().create_timer(0.02 if Game.test_mode else 0.6).timeout
		_entered.clear()
		_redraw()


func _redraw() -> void:
	for slot in _slots:
		slot.queue_redraw()


func _draw_slot(slot: Control, index: int) -> void:
	slot.draw_rect(Rect2(Vector2.ZERO, slot.size), Color(0.1, 0.1, 0.13))
	if index < _entered.size():
		Kit.draw_glyph(slot, slot.size / 2.0, 62.0, _entered[index], GLOW)
	else:
		slot.draw_circle(slot.size / 2.0, 4.0, Color(0.3, 0.3, 0.36))


func _draw_key(face: Control, number: int) -> void:
	Kit.draw_glyph(face, face.size / 2.0, 78.0, number, Color(0.1, 0.1, 0.14))
