extends Node3D
## Room controller: turns mouse input into walking, looking and interacting.
##   Left click  - walk there / interact with a hotspot (using the selected item, if any)
##   Right click - look at a hotspot; also puts away the selected item

@onready var camera: Camera3D = $Camera3D
@onready var player: Player = $Player
@onready var nav_region: NavigationRegion3D = $Nav
@onready var ui: GameUI = $UI


func _ready() -> void:
	# Build the walkable area from the room's colliders (everything under Nav).
	nav_region.bake_navigation_mesh(false)
	Game.say("A cellar. One door, and it doesn't look friendly.")


func _process(_delta: float) -> void:
	ui.set_hover(_hover_text())


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
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
		var item := Game.selected_item
		Game.selected_item = ""
		player.walk_to(hotspot.approach_position(), func() -> void:
			if is_instance_valid(hotspot):
				player.face(hotspot.global_position)
				hotspot.interact(item)
		)
	elif collider is Node and (collider as Node).is_in_group("floor"):
		var point: Vector3 = hit.get("position")
		player.walk_to(point)


func _secondary_click(screen_pos: Vector2) -> void:
	Game.selected_item = ""
	var hit := _pick(screen_pos)
	var hotspot := hit.get("collider") as Hotspot
	if hotspot:
		hotspot.look()


func _hover_text() -> String:
	if get_viewport().gui_get_hovered_control() != null:
		return ""
	var hit := _pick(get_viewport().get_mouse_position())
	var hotspot := hit.get("collider") as Hotspot
	if hotspot == null:
		return ""
	if Game.selected_item != "":
		return "Use %s on %s" % [Game.item_name(Game.selected_item), hotspot.display_name]
	return hotspot.display_name


func _pick(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(query)
