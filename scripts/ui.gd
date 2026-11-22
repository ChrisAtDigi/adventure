class_name GameUI
extends CanvasLayer
## Everything drawn over the 3D view: the narrator's text, inventory, clipboard,
## achievement toasts, close-up puzzle panels, and the title and ending screens.

signal narration_finished

const TYPE_SPEED := 70.0

## Set by Main.
var main: Node
var modal: Control
var ending_shown := false

var _mono: SystemFont
var _serif: SystemFont
var _hover: Label
var _help: Label
var _narration: PanelContainer
var _speaker: Label
var _text: Label
var _inventory: HBoxContainer
var _clipboard_button: Button
var _toast: PanelContainer
var _toast_title: Label
var _toast_sub: Label
var _fade: ColorRect
var _modal_layer: Control
var _modal_dismissable := true

var _lines: Array = []
var _line := ""
var _shown := 0.0
var _hold := 0.0
var _toasts: Array[String] = []
var _toasting := false


func _ready() -> void:
	layer = 10
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	_serif.font_weight = 700

	var root := _full(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hover = Kit.label("", 24, Kit.CREAM)
	_hover.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover.add_theme_constant_override("outline_size", 8)
	_hover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover.anchor_right = 1.0
	_hover.offset_top = 14
	_hover.offset_bottom = 50
	root.add_child(_hover)

	_help = Kit.label("Left click: walk or use      Right click: look      Space: next line      Tab: clipboard      M: mute", 15, Color(0.8, 0.85, 0.9, 0.8))
	_help.add_theme_color_override("font_outline_color", Color.BLACK)
	_help.add_theme_constant_override("outline_size", 5)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.anchor_right = 1.0
	_help.offset_top = 52
	_help.offset_bottom = 76
	_help.visible = false
	root.add_child(_help)

	_inventory = HBoxContainer.new()
	_inventory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory.add_theme_constant_override("separation", 8)
	_inventory.anchor_top = 1.0
	_inventory.anchor_bottom = 1.0
	_inventory.anchor_right = 1.0
	_inventory.offset_left = 16
	_inventory.offset_right = -190
	_inventory.offset_top = -60
	_inventory.offset_bottom = -14
	root.add_child(_inventory)

	_clipboard_button = Kit.button("Clipboard", Vector2(160, 46))
	_clipboard_button.anchor_left = 1.0
	_clipboard_button.anchor_right = 1.0
	_clipboard_button.anchor_top = 1.0
	_clipboard_button.anchor_bottom = 1.0
	_clipboard_button.offset_left = -176
	_clipboard_button.offset_right = -16
	_clipboard_button.offset_top = -60
	_clipboard_button.offset_bottom = -14
	_clipboard_button.pressed.connect(toggle_clipboard)
	root.add_child(_clipboard_button)

	_fade = _full(ColorRect.new())
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	_modal_layer = _full(Control.new())
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_modal_layer)

	_build_narration(root)
	_build_toast(root)

	Game.narration.connect(narrate)
	Game.inventory_changed.connect(_rebuild_inventory)
	Game.selected_item_changed.connect(_rebuild_inventory)
	Game.achievement_unlocked.connect(_on_achievement)
	Game.note_added.connect(func(_note: String) -> void: _clipboard_button.text = "Clipboard  (new)")
	_rebuild_inventory()
	set_hud_visible(false)


func _process(delta: float) -> void:
	if _line == "":
		return
	if _shown < _line.length():
		var before := int(_shown)
		_shown += delta * (100000.0 if Game.test_mode else TYPE_SPEED)
		_text.visible_characters = mini(int(_shown), _line.length())
		if int(_shown) / 3 != before / 3:
			Sfx.play("tick", -26.0)
	else:
		_hold -= delta
		if _hold <= 0.0:
			_next_line()


# --- Heads-up display --------------------------------------------------------

func set_hover(text: String) -> void:
	_hover.text = text


func set_hud_visible(shown: bool) -> void:
	_inventory.visible = shown
	_clipboard_button.visible = shown
	_hover.visible = shown


## Show the controls reminder for a little while.
func show_help() -> void:
	_help.visible = true
	_help.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(14.0)
	tween.tween_property(_help, "modulate:a", 0.0, 1.5)


func fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, 0.02 if Game.test_mode else 0.45)
	await tween.finished


func _rebuild_inventory() -> void:
	for child in _inventory.get_children():
		child.queue_free()
	for id in Game.inventory:
		var button := Kit.button(Game.item_name(id), Vector2(140, 46))
		button.toggle_mode = true
		button.button_pressed = id == Game.selected_item
		button.tooltip_text = Game.ITEMS[id]["desc"]
		button.pressed.connect(_on_item_pressed.bind(id))
		_inventory.add_child(button)


func _on_item_pressed(id: String) -> void:
	Game.selected_item = "" if Game.selected_item == id else id


# --- Narration ---------------------------------------------------------------

func _build_narration(root: Control) -> void:
	_narration = PanelContainer.new()
	_narration.add_theme_stylebox_override("panel", Kit.style(Color(0.03, 0.04, 0.07, 0.93), Color(0.2, 0.45, 0.45), 2, 8, 16))
	_narration.anchor_left = 0.5
	_narration.anchor_right = 0.5
	_narration.anchor_top = 1.0
	_narration.anchor_bottom = 1.0
	_narration.offset_left = -450
	_narration.offset_right = 450
	_narration.offset_top = -196
	_narration.offset_bottom = -72
	_narration.visible = false
	_narration.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			skip_line())
	root.add_child(_narration)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration.add_child(column)
	_speaker = Kit.label("PARK ANNOUNCEMENT", 14, Kit.ORANGE)
	column.add_child(_speaker)
	_text = Kit.label("", 20, Kit.CREAM, _mono)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(860, 0)
	column.add_child(_text)


## Show lines of narration one after another. Replaces anything already showing.
func narrate(lines: Array) -> void:
	_lines = lines.duplicate()
	_next_line()


func is_narrating() -> bool:
	return _line != ""


## Finish typing the current line, or move on to the next one.
func skip_line() -> void:
	if _line == "":
		return
	if _shown < _line.length():
		_shown = _line.length()
		_text.visible_characters = -1
	else:
		_next_line()


func _next_line() -> void:
	if _lines.is_empty():
		var was_narrating := _line != ""
		_line = ""
		_narration.visible = false
		if was_narrating:
			narration_finished.emit()
		return
	var line: String = _lines.pop_front()
	var from_pa := line.begins_with("PA: ")
	_line = line.trim_prefix("PA: ")
	_speaker.visible = from_pa
	_text.add_theme_color_override("font_color", Kit.TEAL if from_pa else Kit.CREAM)
	_text.text = _line
	_text.visible_characters = 0
	_shown = 0.0
	_hold = 0.0 if Game.test_mode else 1.6 + _line.length() * 0.05
	_narration.visible = true


# --- Achievements ------------------------------------------------------------

func _build_toast(root: Control) -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", Kit.style(Color(0.1, 0.07, 0.03, 0.95), Kit.ORANGE, 2, 8, 12))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.anchor_left = 1.0
	_toast.anchor_right = 1.0
	_toast.offset_left = -400
	_toast.offset_right = -16
	_toast.offset_top = 16
	_toast.offset_bottom = 100
	_toast.visible = false
	root.add_child(_toast)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(column)
	column.add_child(Kit.label("ACHIEVEMENT", 13, Kit.ORANGE))
	_toast_title = Kit.label("", 20, Kit.CREAM)
	column.add_child(_toast_title)
	_toast_sub = Kit.label("", 15, Color(0.8, 0.78, 0.7), _mono)
	column.add_child(_toast_sub)


func _on_achievement(id: String) -> void:
	_toasts.append(id)
	if not _toasting:
		_run_toasts()


func _run_toasts() -> void:
	_toasting = true
	while not _toasts.is_empty():
		var info: Dictionary = Game.ACHIEVEMENTS[_toasts.pop_front()]
		_toast_title.text = info["title"]
		_toast_sub.text = "%s  +%d" % [info["sub"], info["points"]]
		_toast.modulate.a = 0.0
		_toast.visible = true
		Sfx.play("achieve", -14.0)
		var tween := create_tween()
		tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
		tween.tween_interval(0.05 if Game.test_mode else 3.2)
		tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
		await tween.finished
	_toast.visible = false
	_toasting = false


# --- Close-ups and screens ---------------------------------------------------

func modal_open() -> bool:
	return modal != null


func open_modal(panel: Control, dismissable := true) -> void:
	close_modal()
	modal = panel
	_modal_dismissable = dismissable
	_modal_layer.add_child(panel)
	set_hover("")


func close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null


## Close whatever close-up is open, unless it is the title or ending screen.
func dismiss() -> void:
	if modal and _modal_dismissable:
		close_modal()


func open_keypad() -> void:
	var panel := KeypadPanel.new()
	panel.ui = self
	panel.solved.connect(func() -> void:
		await get_tree().create_timer(0.02 if Game.test_mode else 0.9).timeout
		if modal == panel:
			close_modal())
	open_modal(panel)


func open_breakers() -> void:
	var panel := BreakerPanel.new()
	panel.ui = self
	open_modal(panel)


func toggle_clipboard() -> void:
	if modal:
		dismiss()
		return
	_clipboard_button.text = "Clipboard"
	var paper := Kit.style(Color(0.95, 0.91, 0.8), Color(0.42, 0.28, 0.15), 8, 6, 24)
	var panel := _centered_panel(paper, Vector2(880, 500), -40)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(Kit.label("INSPECTION NOTES: WYRMHOLLOW DRAGON PARK", 22, Kit.INK, _serif))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var notes := VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_constant_override("separation", 8)
	scroll.add_child(notes)
	if Game.notes.is_empty():
		notes.add_child(_wrapped("Nothing noted yet. Look at things. It is, after all, the job.", 17, Color(0.35, 0.33, 0.3), 500))
	for note in Game.notes:
		notes.add_child(_wrapped("- " + note, 17, Kit.INK, 500))

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(290, 0)
	side.add_theme_constant_override("separation", 4)
	body.add_child(side)
	side.add_child(Kit.label("SCORE", 15, Color(0.5, 0.3, 0.1)))
	side.add_child(_wrapped("%d of a possible %d" % [Game.score(), Game.MAX_SCORE], 20, Kit.INK, 290))
	side.add_child(Kit.label(" ", 8, Kit.INK))
	side.add_child(Kit.label("ACHIEVEMENTS", 15, Color(0.5, 0.3, 0.1)))
	if Game.achievements.is_empty():
		side.add_child(_wrapped("None. The cave is unimpressed.", 15, Color(0.35, 0.33, 0.3), 290))
	for id in Game.achievements:
		side.add_child(_wrapped(Game.ACHIEVEMENTS[id]["title"], 15, Kit.INK, 290))

	var close := Kit.button("Put the clipboard away")
	close.pressed.connect(close_modal)
	column.add_child(close)
	open_modal(panel.get_parent())


func show_title() -> void:
	var screen := _screen(Color(0.01, 0.01, 0.03, 0.8))
	var column := _screen_column(screen)
	var title := Kit.label("ADVENTURE", 124, Kit.CREAM, _serif)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.25))
	title.add_theme_constant_override("outline_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_centered_label("Chapter One: Sign Here", 30, Kit.TEAL, _mono))
	column.add_child(Kit.label(" ", 24, Kit.INK))

	var start := Kit.button("New game", Vector2(260, 52))
	start.pressed.connect(func() -> void: main.start_new())
	column.add_child(_centered(start))
	if Game.has_save():
		var resume := Kit.button("Continue", Vector2(260, 52))
		resume.pressed.connect(func() -> void: main.continue_game())
		column.add_child(_centered(resume))
	var quit := Kit.button("Quit", Vector2(260, 52))
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(_centered(quit))

	column.add_child(Kit.label(" ", 16, Kit.INK))
	column.add_child(_centered_label("Left click to walk or use.  Right click to look.  Tab opens your clipboard.", 16, Color(0.75, 0.78, 0.82), null))
	open_modal(screen, false)


func show_ending() -> void:
	ending_shown = true
	var screen := _screen(Color(0, 0, 0, 1))
	var column := _screen_column(screen)
	column.add_child(_centered_label("END OF CHAPTER ONE", 64, Kit.CREAM, _serif))
	column.add_child(_centered_label("You are going down.", 26, Kit.TEAL, _mono))
	column.add_child(Kit.label(" ", 20, Kit.INK))
	column.add_child(_centered_label("Score: %d of a possible %d." % [Game.score(), Game.MAX_SCORE], 24, Kit.CREAM, _mono))
	column.add_child(_centered_label("Achievements: %d of %d." % [Game.achievements.size(), Game.ACHIEVEMENTS.size()], 20, Kit.CREAM, _mono))
	column.add_child(_centered_label("The cave is keeping count.", 20, Color(0.6, 0.62, 0.66), _mono))
	column.add_child(Kit.label(" ", 20, Kit.INK))
	var again := Kit.button("Play again", Vector2(260, 52))
	again.pressed.connect(func() -> void: main.start_new())
	column.add_child(_centered(again))
	var quit := Kit.button("Quit", Vector2(260, 52))
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(_centered(quit))
	open_modal(screen, false)


# --- Layout helpers ----------------------------------------------------------

func _full(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


## A full-screen shade holding one centred panel. Returns the panel.
func _centered_panel(panel_style: StyleBoxFlat, size: Vector2, lift: float) -> PanelContainer:
	var screen := _screen(Color(0, 0, 0, 0.55))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_top = -size.y / 2.0 + lift
	panel.offset_bottom = size.y / 2.0 + lift
	screen.add_child(panel)
	return panel


func _screen(shade: Color) -> Control:
	var screen := _full(Control.new())
	var backdrop := _full(ColorRect.new()) as ColorRect
	backdrop.color = shade
	screen.add_child(backdrop)
	return screen


func _screen_column(screen: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	screen.add_child(column)
	return column


func _centered(control: Control) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.add_child(control)
	return holder


func _centered_label(text: String, size: int, color: Color, font: Font) -> Label:
	var item := Kit.label(text, size, color, font)
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return item


func _wrapped(text: String, size: int, color: Color, width: float) -> Label:
	var item := Kit.label(text, size, color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.custom_minimum_size = Vector2(width, 0)
	return item
