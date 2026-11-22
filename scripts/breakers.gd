class_name BreakerPanel
extends Control
## Close-up of the park's power board. The generator can carry a load of 5.
## The lift needs 3, and the jingle cannot be turned off.

const CAPACITY := 5
const ROWS := [
	{"id": "fences", "label": "ENCLOSURE FENCES", "load": 3},
	{"id": "heat", "label": "HATCHERY HEAT LAMPS", "load": 1},
	{"id": "jingle", "label": "GIFT SHOP JINGLE", "load": 1},
	{"id": "lift", "label": "SERVICE LIFT", "load": 3},
]
const ON := Color(0.3, 0.95, 0.4)
const OFF := Color(0.5, 0.2, 0.18)

## Set by GameUI before the panel is shown.
var ui: GameUI

var _switches := {}
var _gauge: Control
var _reading: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.style(Color(0.4, 0.42, 0.46), Color(0.16, 0.17, 0.2), 6, 8, 22))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -330
	panel.offset_bottom = 60
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(Kit.label("MAIN DISTRIBUTION BOARD", 24, Kit.INK))

	var meter := HBoxContainer.new()
	meter.add_theme_constant_override("separation", 14)
	column.add_child(meter)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(330, 34)
	_gauge.draw.connect(_draw_gauge)
	meter.add_child(_gauge)
	_reading = Kit.label("", 20, Kit.INK)
	meter.add_child(_reading)

	for row: Dictionary in ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		column.add_child(line)
		var name_label := Kit.label(row["label"], 20, Kit.INK)
		name_label.custom_minimum_size = Vector2(300, 0)
		line.add_child(name_label)
		var load_label := Kit.label("load %d" % row["load"], 18, Color(0.2, 0.2, 0.24))
		load_label.custom_minimum_size = Vector2(90, 0)
		line.add_child(load_label)
		var switch := Kit.button("", Vector2(110, 42))
		switch.pressed.connect(toggle.bind(row["id"]))
		line.add_child(switch)
		_switches[row["id"]] = switch

	var back := Kit.button("Step away")
	back.pressed.connect(func() -> void: ui.close_modal())
	column.add_child(back)
	_refresh()


func is_on(id: String) -> bool:
	match id:
		"fences":
			return not Game.flag("fences_off")
		"heat":
			return not Game.flag("heat_off")
		"lift":
			return Game.flag("lift_on")
	return true


func total_load() -> int:
	var total := 0
	for row: Dictionary in ROWS:
		if is_on(row["id"]):
			total += int(row["load"])
	return total


## Flip a breaker, if the board allows it.
func toggle(id: String) -> void:
	if id == "jingle":
		Sfx.play("error")
		Game.award("jingle")
		Game.say("You flip the jingle breaker off. It flips itself back on. It has never been off. People have tried.")
		return

	var turning_on := not is_on(id)
	var needed := 0
	for row: Dictionary in ROWS:
		if row["id"] == id:
			needed = int(row["load"])
	if turning_on and total_load() + needed > CAPACITY:
		Sfx.play("error")
		Game.award("overload")
		Game.say([
			"The breaker thinks about it, then throws itself back. Too much load. The lights flicker.",
			"In the flicker, the room is briefly fuller than it should be.",
		])
		return

	Sfx.play("thunk")
	match id:
		"fences":
			Game.set_flag("fences_off", not turning_on)
			if turning_on:
				Game.say("You switch the enclosure fences back on. It feels responsible. It also feels late.")
			else:
				Game.award("fences")
				Game.say([
					"You switch off the enclosure fences.",
					"Somewhere out in the dark, three gates unlock, politely.",
				])
		"heat":
			Game.set_flag("heat_off", not turning_on)
			if turning_on:
				Game.say("The heat lamps come back on. Something in the Hatchery settles.")
			else:
				Game.say("The heat lamps go out. Something in the Hatchery will have opinions about that.")
		"lift":
			Game.set_flag("lift_on", turning_on)
			if turning_on:
				Sfx.play("power")
				Game.say("Power to the lift. Beside its doors, nine old stone buttons begin to glow.")
			else:
				Game.say("The lift goes dark. For a moment you feel safer.")
	_refresh()


func _refresh() -> void:
	for id: String in _switches:
		var switch: Button = _switches[id]
		var on := is_on(id)
		switch.text = "ON" if on else "OFF"
		switch.add_theme_color_override("font_color", ON if on else Color(1.0, 0.55, 0.5))
	_reading.text = "LOAD %d of %d" % [total_load(), CAPACITY]
	_gauge.queue_redraw()


func _draw_gauge() -> void:
	var load := total_load()
	for i in CAPACITY:
		var cell := Rect2(Vector2(i * 66.0, 0), Vector2(58, 34))
		_gauge.draw_rect(cell, ON if i < load else Color(0.18, 0.2, 0.22))
		_gauge.draw_rect(cell, Kit.INK, false, 2.0)
