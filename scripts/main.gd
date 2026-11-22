extends Node
## Runs the game: owns the player, the interface and the current room, turns mouse
## input into walking and interacting, and moves the player between rooms.
##   Left click  - walk there, or use a hotspot (with the selected item, if any)
##   Right click - look at a hotspot; also puts away the selected item

const ROOMS := {
	"lobby": preload("res://scripts/rooms/lobby.gd"),
	"hatchery": preload("res://scripts/rooms/hatchery.gd"),
	"control": preload("res://scripts/rooms/control.gd"),
}

var room: Room
var player: Player
var ui: GameUI
## True during room changes and cutscenes: the world ignores clicks.
var locked := false


func _ready() -> void:
	player = Player.new()
	player.visible = false
	add_child(player)
	ui = GameUI.new()
	ui.main = self
	add_child(ui)
	Game.flag_changed.connect(func(_flag: String) -> void:
		if room:
			room.refresh())

	# The title screen sits over an empty Arrivals Hall.
	Game.reset()
	_load_room("lobby", "default")
	ui.show_title()


func start_new() -> void:
	Game.reset()
	await _begin("lobby")
	ui.show_help()
	Game.say([
		"You are standing in the Arrivals Hall of Wyrmhollow Dragon Park. It opens to the public tomorrow.",
		"You are a health and safety inspector. You have a clipboard, a hard hat, and a bad feeling.",
		"The staff were meant to meet you. There are no staff. There is a jingle.",
		"The doors you came in by have locked themselves behind you. They do that.",
		"PA: Welcome to Wyrmhollow! Please keep arms, legs and expectations inside the walkways.",
	])


func continue_game() -> void:
	if Game.load_game():
		await _begin(Game.room_id)
	else:
		start_new()


## Walk through a door: fade out, swap the room, fade in.
func go_to(room_id: String) -> void:
	if locked:
		return
	locked = true
	var from := Game.room_id
	await ui.fade_to(1.0)
	_load_room(room_id, from)
	await _settle()
	Game.save_game()
	await ui.fade_to(0.0)
	locked = false
	room.entered(from)


## The end of Chapter One: into the lift.
func finish_chapter() -> void:
	if locked:
		return
	locked = true
	ui.set_hover("")
	Sfx.play("thunk")
	Game.say([
		"You step into the lift. The doors close behind you with the soft confidence of a thing that has done this before.",
		"Something lands on your hard hat. It is the hatchling. It rings the bell once, like a conductor.",
		"There is one button inside. It is already pressed.",
		"You are in a lift. It is going down. Exits: none.",
		"PA: Thank you for visiting Wyrmhollow! Mind the gap. Mind what is in the gap.",
		"The lights go out. Far below, something rings a bell back.",
		"The hatchling is not ringing its bell. You checked.",
	])
	await ui.narration_finished
	await ui.fade_to(1.0)
	Game.set_flag("chapter_one_done")
	ui.set_hud_visible(false)
	ui.show_ending()


## Use a hotspot with whatever item is selected: walk over, then act.
func interact(hotspot: Hotspot) -> void:
	var item := Game.selected_item
	Game.selected_item = ""
	player.walk_to(hotspot.approach, func() -> void:
		if is_instance_valid(hotspot) and hotspot.is_inside_tree():
			player.face(hotspot.global_position)
			hotspot.use_handler.call(item))


func _begin(room_id: String) -> void:
	locked = true
	await ui.fade_to(1.0)
	ui.close_modal()
	ui.ending_shown = false
	_load_room(room_id, "default")
	player.visible = true
	ui.set_hud_visible(true)
	await _settle()
	Game.save_game()
	await ui.fade_to(0.0)
	locked = false


func _load_room(room_id: String, from: String) -> void:
	if room:
		room.free()
	var script: GDScript = ROOMS[room_id]
	room = script.new()
	room.name = room_id
	room.main = self
	add_child(room)
	Game.room_id = room_id
	Sfx.set_room(room_id)
	player.stop()
	player.global_position = room.spawns.get(from, room.spawns["default"])
	player.rotation.y = 0.5


## Wait for the navigation map to pick up the new room's walkable area, so the
## first click after a door always finds a path.
func _settle() -> void:
	var map := room.get_world_3d().navigation_map
	for i in 120:
		await get_tree().physics_frame
		var here := player.global_position
		var nearest := NavigationServer3D.map_get_closest_point(map, here)
		if i >= 2 and Vector2(nearest.x - here.x, nearest.z - here.z).length() < 0.5:
			return


func _process(_delta: float) -> void:
	ui.set_hover(_hover_text())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_SPACE, KEY_ENTER:
				ui.skip_line()
			KEY_TAB:
				if not locked and player.visible:
					ui.toggle_clipboard()
			KEY_ESCAPE:
				ui.dismiss()
			KEY_M:
				Sfx.toggle_mute()
		return

	var click := event as InputEventMouseButton
	if click == null or not click.pressed or locked or ui.modal_open():
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		_primary_click(click.position)
		get_viewport().set_input_as_handled()
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		_secondary_click(click.position)
		get_viewport().set_input_as_handled()


func _primary_click(screen_pos: Vector2) -> void:
	var hit := _pick(screen_pos)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	var hotspot := collider as Hotspot
	if hotspot:
		interact(hotspot)
	elif collider is Node and (collider as Node).is_in_group("floor"):
		var point: Vector3 = hit.get("position")
		player.walk_to(point)


func _secondary_click(screen_pos: Vector2) -> void:
	Game.selected_item = ""
	var hotspot := _pick(screen_pos).get("collider") as Hotspot
	if hotspot:
		hotspot.look_handler.call()


func _hover_text() -> String:
	if locked or ui.modal_open() or get_viewport().gui_get_hovered_control() != null:
		return ""
	var hotspot := _pick(get_viewport().get_mouse_position()).get("collider") as Hotspot
	if hotspot == null:
		return ""
	if Game.selected_item != "":
		return "Use %s on %s" % [Game.item_name(Game.selected_item).to_lower(), hotspot.display_name]
	return hotspot.display_name


func _pick(screen_pos: Vector2) -> Dictionary:
	var camera := room.camera
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return room.get_world_3d().direct_space_state.intersect_ray(query)
