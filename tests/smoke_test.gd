extends Node
## Plays the prototype puzzle start to finish with simulated mouse clicks.
## Run:  godot --path . res://tests/smoke_test.tscn
## Set the SMOKE_OUT environment variable to a folder to also save screenshots there.
## Exit code is the number of failed checks.

const ROOM := preload("res://scenes/room.tscn")

var _room: Node3D
var _player: Player
var _camera: Camera3D
var _failures := 0
var _last_message := ""


func _ready() -> void:
	Game.message.connect(func(text: String) -> void: _last_message = text)
	_room = ROOM.instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	_camera = _room.get_node("Camera3D")
	await _frames(10)

	var nav: NavigationRegion3D = _room.get_node("Nav")
	_check("navmesh baked", nav.navigation_mesh.get_polygon_count() > 0)
	await _screenshot("01_start")

	var start := _player.global_position
	await _click(Vector3(-1.0, 0.0, 1.5))
	_check("walks to a floor click", _player.global_position.distance_to(Vector3(-1.0, 0.0, 1.5)) < 0.3
			and start.distance_to(_player.global_position) > 1.0)

	var door := _room.get_node("Nav/Door")
	var crate := _room.get_node("Nav/Crate")

	await _click(Vector3(2.0, 1.0, -3.9))
	_check("door starts locked", not door.open and _last_message.begins_with("Locked"))

	await _click(Vector3(-3.0, 0.5, -2.5))
	_check("crate needs a tool", crate.state == 0)

	await _click(Vector3(-4.75, 0.5, 2.0))
	_check("picks up crowbar", Game.has_item("crowbar"))
	_check("crowbar leaves the room", not _room.has_node("Nav/Crowbar"))

	Game.selected_item = "crowbar"
	await _click(Vector3(-3.0, 0.5, -2.5))
	_check("crowbar opens crate", crate.state == 1)
	_check("item is put away after use", Game.selected_item == "")

	await _click(Vector3(-3.0, 0.5, -2.5))
	_check("takes key from crate", Game.has_item("key") and crate.state == 2)

	Game.selected_item = "key"
	await _click(Vector3(2.0, 1.0, -3.9))
	_check("key opens door", door.open)
	_check("key is used up", not Game.has_item("key"))

	await get_tree().create_timer(1.2).timeout
	await _screenshot("02_solved")

	print("SMOKE TEST: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_failures += 1
		print("      last message: ", _last_message)
		print("      player at: ", _player.global_position)


## Left-click the screen position of a 3D point, then wait for the walk to finish.
func _click(world_point: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _camera.unproject_position(world_point)
	event.global_position = event.position
	get_viewport().push_input(event)
	await _frames(2)
	var waited := 0
	while _player.is_walking() and waited < 900:
		await get_tree().process_frame
		waited += 1
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _screenshot(file_name: String) -> void:
	var folder := OS.get_environment("SMOKE_OUT")
	if folder == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder.path_join(file_name + ".png"))
