class_name Room
extends Node3D
## Base class for a room. A room script overrides build() to construct the set and
## its hotspots, and refresh() to make the set match the story flags.
##
## Rooms are rebuilt from the flags every time the player walks in, so nothing
## about a room needs saving beyond what is in Game.flags.

const OUTLINE := preload("res://shaders/outline.gdshader")
const REFUSALS := [
	"The %s and the %s have nothing to say to each other.",
	"You try the %s on the %s. It goes exactly as well as it sounds.",
	"That is not what the %s is for. The %s agrees.",
]

## Set by Main before the room enters the tree.
var main: Node
var nav: NavigationRegion3D
var camera: Camera3D
var hotspots := {}
## Where the inspector appears, keyed by the room they came from.
var spawns := {"default": Vector3.ZERO}

var _built := false
var _refusal := 0


func _ready() -> void:
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.navigation_mesh = mesh
	add_child(nav)

	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_add_outline()

	build()
	refresh()
	_built = true
	# The walkable area is whatever floor is left once the colliders are cut out.
	nav.bake_navigation_mesh(false)


## Construct the set. Override.
func build() -> void:
	pass


## Make the set match Game.flags. Called after build() and whenever a flag changes. Override.
func refresh() -> void:
	pass


## Called once the player has arrived and the screen has faded in. Override.
func entered(_from: String) -> void:
	pass


# --- Set building ------------------------------------------------------------

## Place the fixed camera.
func shot(from: Vector3, target: Vector3, fov := 45.0) -> void:
	camera.fov = fov
	camera.look_at_from_position(from, target)


func mood(ambient: Color, ambient_energy: float, sun: Color, sun_energy: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.015, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, 35, 0)
	light.light_color = sun
	light.light_energy = sun_energy
	light.shadow_enabled = true
	add_child(light)


func floor_slab(width: float, depth: float, color: Color) -> void:
	var body := _solid(Vector3(0, -0.15, 0), Vector3(width, 0.3, depth), color)
	body.add_to_group("floor")


## The two walls the camera can see: the back one and the left one.
func walls(width: float, depth: float, height: float, back: Color, left: Color) -> void:
	_solid(Vector3(-0.15, height / 2.0, -depth / 2.0 - 0.15), Vector3(width + 0.3, height, 0.3), back)
	_solid(Vector3(-width / 2.0 - 0.15, height / 2.0, 0), Vector3(0.3, height, depth), left)


## An invisible obstacle the inspector has to walk around.
func block(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	_collider(body, size)
	nav.add_child(body)
	return body


## Add something the player can look at and use.
## `look` is a line, an array of lines, or a function. `use` receives the item id
## being used ("" for none); without one, clicking just looks.
func spot(id: String, title: String, pos: Vector3, size: Vector3, approach: Vector3,
		look: Variant, use := Callable()) -> Hotspot:
	var hotspot := Hotspot.new()
	hotspot.id = id
	hotspot.name = id
	hotspot.display_name = title
	hotspot.approach = approach
	hotspot.position = pos
	_collider(hotspot, size)
	hotspot.look_handler = func() -> void: _look(look)
	hotspot.use_handler = func(item: String) -> void:
		if use.is_valid():
			use.call(item)
		elif item == "":
			_look(look)
		else:
			refuse(item, title)
	nav.add_child(hotspot)
	hotspots[id] = hotspot
	return hotspot


## The stock answer to using an item on something that doesn't want it.
func refuse(item: String, title: String) -> void:
	var names := [Game.item_name(item).to_lower(), title]
	Game.say(REFUSALS[_refusal % REFUSALS.size()] % names)
	_refusal += 1


## Move a set piece to match the story: animated if the player is watching,
## instant while the room is still being built.
func ease_to(node: Node3D, property: String, value: Variant, seconds := 0.6) -> void:
	if _built and not Game.test_mode:
		create_tween().set_trans(Tween.TRANS_QUAD).tween_property(node, property, value, seconds)
	else:
		node.set_indexed(property, value)


func _look(look: Variant) -> void:
	if look is Callable:
		look.call()
	else:
		Game.say(look)


func _solid(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := block(pos, size)
	Kit.box(body, Vector3.ZERO, size, color)
	return body


func _collider(body: Node3D, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)


func _add_outline() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var material := ShaderMaterial.new()
	material.shader = OUTLINE
	material.render_priority = -100
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.extra_cull_margin = 16384.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(instance)
