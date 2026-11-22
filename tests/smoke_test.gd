extends Node
## Plays Chapter One from the title screen to the ending, the way a player would:
## every action walks the inspector to the hotspot and uses it.
## Run:  godot --path . res://tests/smoke_test.tscn
## Set the SMOKE_OUT environment variable to a folder to also save screenshots there.
## Exit code is the number of failed checks.

const MAIN := preload("res://scenes/main.tscn")

var _main: Node
var _failures := 0
var _said: Array = []


func _ready() -> void:
	Game.test_mode = true
	Game.narration.connect(func(lines: Array) -> void: _said = lines)
	_main = MAIN.instantiate()
	add_child(_main)
	await _frames(10)
	_check("title screen is up", _main.ui.modal_open() and not _main.player.visible)
	await _shot("00_title")

	_main.start_new()
	await _idle()
	_check("new game starts in the Arrivals Hall", Game.room_id == "lobby" and _main.player.visible)
	_check_reachable()
	await _shot("01_lobby")

	# A real mouse click on the floor walks the inspector there.
	var floor_point := Vector3(-1.0, 0.0, 1.5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _main.room.camera.unproject_position(floor_point)
	click.global_position = click.position
	get_viewport().push_input(click)
	await _idle()
	_check("floor click walks there", _main.player.global_position.distance_to(floor_point) < 0.4)

	# --- Arrivals Hall ---
	await _use("turnstile")
	_check("turnstile starts locked", Game.room_id == "lobby" and not Game.flag("turnstile_open"))
	await _use("staff_door")
	_check("staff door starts locked", Game.room_id == "lobby")
	await _use("cinders")
	_check("statue is jammed without a tool", not Game.has_item("token"))
	await _use("picker")
	_check("picks up litter picker", Game.has_item("picker"))
	await _use("cinders", "picker")
	_check("picker fishes out the token", Game.has_item("token"))
	await _use("bell")
	_check("bell rings first", Game.flag("bell_rung") and not Game.has_item("bell"))
	await _use("bell")
	_check("bell is taken second", Game.has_item("bell"))
	await _use("leaflets")
	_check("leaflet adds species notes", Game.notes.size() >= 3)
	_main.room.hotspots["carving"].look_handler.call()
	await _use("desk")

	# One line at real speed, to photograph the narrator's text box.
	Game.test_mode = false
	Game.say("You are in the Arrivals Hall. There is a jingle. Exits: a turnstile, a staff door, and the way you came in, which has locked itself.")
	await get_tree().create_timer(2.6).timeout
	await _shot("01b_narration")
	Game.test_mode = true
	_main.ui.skip_line()
	_main.ui.skip_line()

	await _use("turnstile", "token")
	_check("token opens turnstile", Game.flag("turnstile_open") and not Game.has_item("token"))
	await _shot("02_lobby_open")
	await _use("turnstile")
	_check("turnstile leads to the Hatchery", Game.room_id == "hatchery")

	# --- Hatchery ---
	_check_reachable()
	await _shot("03_hatchery")
	for bay in ["bay1", "bay2", "bay3"]:
		await _use(bay)
	await _use("logbook")
	await _use("window")
	await _use("hatchling")
	_check("hatchling keeps the pass for nothing", not Game.has_item("pass"))
	await _use("hatchling", "bell")
	_check("bell buys the staff pass", Game.has_item("pass") and not Game.has_item("bell"))
	await _use("exit")
	_check("exit leads back to Arrivals", Game.room_id == "lobby")

	# --- Control Room ---
	await _use("staff_door", "pass")
	_check("pass opens staff door", Game.flag("staff_door_open"))
	await _use("staff_door")
	_check("staff door leads to the Control Room", Game.room_id == "control")
	_check_reachable()
	await _shot("04_control")
	await _use("monitors")
	await _use("lift")
	_check("lift is dead without power", not _main.ui.modal_open())

	await _use("breakers")
	_check("power board opens", _main.ui.modal is BreakerPanel)
	var board: BreakerPanel = _main.ui.modal
	board.toggle("lift")
	_check("lift overloads the board at first", not Game.flag("lift_on"))
	board.toggle("jingle")
	_check("the jingle cannot be stopped", board.is_on("jingle"))
	board.toggle("fences")
	board.toggle("lift")
	_check("lift powers up once the fences are off", Game.flag("lift_on") and board.total_load() <= BreakerPanel.CAPACITY)
	await _frames(3)
	await _shot("05_breakers")
	_main.ui.close_modal()
	await _frames(2)

	await _use("lift")
	_check("keypad opens", _main.ui.modal is KeypadPanel)
	var keypad: KeypadPanel = _main.ui.modal
	for number in [1, 2, 3]:
		keypad.press(number)
	await _frames(8)
	_check("wrong code is rejected", not Game.flag("lift_open"))
	keypad.press(6)
	keypad.press(4)
	await _frames(3)
	await _shot("06_keypad")
	keypad.press(8)
	_check("incubation days open the lift", Game.flag("lift_open"))
	await _frames(12)
	_check("keypad closes itself", not _main.ui.modal_open())
	await _shot("07_lift_open")

	_main.ui.toggle_clipboard()
	await _frames(3)
	await _shot("08_clipboard")
	_main.ui.close_modal()

	await _use("lift")
	var waited := 0
	while not _main.ui.ending_shown and waited < 600:
		await get_tree().process_frame
		waited += 1
	_check("chapter ends in the lift", _main.ui.ending_shown and Game.flag("chapter_one_done"))
	_check("every achievement can be earned", Game.achievements.size() == Game.ACHIEVEMENTS.size())
	await _frames(3)
	await _shot("09_ending")

	print("SMOKE TEST: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_failures += 1
		print("      room: %s   said: %s" % [Game.room_id, _said])


## Every hotspot must be clickable from the room's camera, and its approach
## point must be somewhere the inspector can actually walk to.
func _check_reachable() -> void:
	var room: Room = _main.room
	var space := room.get_world_3d().direct_space_state
	var map := room.get_world_3d().navigation_map
	for id: String in room.hotspots:
		var hotspot: Hotspot = room.hotspots[id]
		if hotspot.collision_layer == 0:
			continue
		var from := room.camera.global_position
		var to := from + (hotspot.global_position - from) * 1.2
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		_check("%s/%s is clickable" % [room.name, id], hit.get("collider") == hotspot)
		var reachable := NavigationServer3D.map_get_closest_point(map, hotspot.approach)
		_check("%s/%s can be walked to" % [room.name, id], reachable.distance_to(hotspot.approach) < 0.6)


## Use a hotspot (optionally with an inventory item) and wait for things to settle.
func _use(id: String, item := "") -> void:
	Game.selected_item = item
	_main.interact(_main.room.hotspots[id])
	await _idle()


func _idle() -> void:
	await _frames(3)
	var waited := 0
	while (_main.locked or _main.player.is_walking()) and waited < 1200:
		await get_tree().process_frame
		waited += 1
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	var folder := OS.get_environment("SMOKE_OUT")
	if folder == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(file_name + ".png"))
