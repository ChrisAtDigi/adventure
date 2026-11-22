class_name Kit
## Building blocks for the game's look: cartoon-shaded shapes, signs, cave glyphs,
## the hatchling, and matching interface pieces. Everything on screen is made here.

const INK := Color(0.07, 0.07, 0.1)
const CREAM := Color(0.96, 0.92, 0.82)
const TEAL := Color(0.25, 0.8, 0.75)
const ORANGE := Color(1.0, 0.6, 0.15)

static var _materials := {}


## Cartoon material, shared between every shape of the same colour.
static func mat(color: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), glow]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.roughness = 1.0
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = material
	return material


static func box(parent: Node, pos: Vector3, size: Vector3, color: Color,
		rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, rot, color, glow)


## Upright cylinder. Pass `top_radius` for a taper (0 makes a cone).
static func cyl(parent: Node, pos: Vector3, radius: float, height: float, color: Color,
		rot := Vector3.ZERO, top_radius := -1.0, glow := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	return _add(parent, mesh, pos, rot, color, glow)


static func ball(parent: Node, pos: Vector3, radius: float, color: Color,
		squash := Vector3.ONE, glow := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var instance := _add(parent, mesh, pos, Vector3.ZERO, color, glow)
	instance.scale = squash
	return instance


static func _add(parent: Node, mesh: PrimitiveMesh, pos: Vector3, rot: Vector3,
		color: Color, glow: float) -> MeshInstance3D:
	mesh.material = mat(color, glow)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation_degrees = rot
	parent.add_child(instance)
	return instance


## Painted lettering. Faces +Z unless rotated.
static func text(parent: Node, pos: Vector3, string: String, px: int, color: Color,
		rot := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = string
	label.font_size = px
	label.outline_size = 0
	label.modulate = color
	label.position = pos
	label.rotation_degrees = rot
	label.line_spacing = -4.0
	parent.add_child(label)
	return label


static func lamp(parent: Node, pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = pos
	parent.add_child(light)
	return light


# --- Cave glyphs -------------------------------------------------------------
# The cave counts in claw marks: one stroke each for 1 to 4, an upturned V for 5,
# and a V followed by strokes for 6 to 9.

static func glyph_strokes(n: int) -> int:
	return n % 5 if n >= 5 else n


## A glyph carved onto a surface. Built in the XY plane, facing +Z unless rotated.
static func glyph3d(parent: Node, pos: Vector3, n: int, size: float, color: Color,
		rot := Vector3.ZERO, glow := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = rot
	parent.add_child(root)
	var has_v := n >= 5
	var strokes := glyph_strokes(n)
	var v_width := 0.42 * size
	var gap := 0.17 * size
	var height := 0.6 * size
	var total := (v_width if has_v else 0.0) + strokes * gap + (0.08 * size if has_v and strokes > 0 else 0.0)
	var x := -total / 2.0
	var bar := Vector3(0.07 * size, height * 1.05, 0.02)
	if has_v:
		box(root, Vector3(x + v_width * 0.25, 0, 0), bar, color, Vector3(0, 0, -19), glow)
		box(root, Vector3(x + v_width * 0.75, 0, 0), bar, color, Vector3(0, 0, 19), glow)
		x += v_width + 0.08 * size
	for i in strokes:
		box(root, Vector3(x + gap * 0.5, 0, 0), Vector3(0.07 * size, height, 0.02), color, Vector3(0, 0, -5), glow)
		x += gap
	return root


## The same glyph drawn on an interface element (call from its `draw` signal).
static func draw_glyph(canvas: CanvasItem, center: Vector2, size: float, n: int, color: Color) -> void:
	var has_v := n >= 5
	var strokes := glyph_strokes(n)
	var v_width := 0.42 * size
	var gap := 0.17 * size
	var height := 0.6 * size
	var total := (v_width if has_v else 0.0) + strokes * gap + (0.08 * size if has_v and strokes > 0 else 0.0)
	var x := center.x - total / 2.0
	var top := center.y - height / 2.0
	var bottom := center.y + height / 2.0
	var width := maxf(2.0, 0.075 * size)
	if has_v:
		var points := PackedVector2Array([Vector2(x, bottom), Vector2(x + v_width / 2.0, top), Vector2(x + v_width, bottom)])
		canvas.draw_polyline(points, color, width, true)
		x += v_width + 0.08 * size
	for i in strokes:
		var mid := x + gap * 0.5
		canvas.draw_line(Vector2(mid + 0.025 * size, top), Vector2(mid - 0.025 * size, bottom), color, width, true)
		x += gap


# --- Creatures ---------------------------------------------------------------

## A Magpie Wyrm hatchling: cat-sized, the colour of a bruise. Faces +Z.
static func hatchling(parent: Node, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var hide := Color(0.45, 0.31, 0.6)
	var dark := Color(0.3, 0.2, 0.42)
	ball(root, Vector3(0, 0.2, 0), 0.2, hide, Vector3(1, 0.9, 1.25))
	ball(root, Vector3(0, 0.16, 0.1), 0.15, Color(0.72, 0.6, 0.8), Vector3(1, 0.9, 1.1))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.42, 0.18)
	root.add_child(head)
	ball(head, Vector3.ZERO, 0.15, hide)
	box(head, Vector3(0, -0.03, 0.15), Vector3(0.12, 0.09, 0.14), hide)
	for side in [-1.0, 1.0]:
		ball(head, Vector3(0.08 * side, 0.05, 0.1), 0.052, Color(1.0, 0.85, 0.2), Vector3.ONE, 0.6)
		ball(head, Vector3(0.085 * side, 0.05, 0.146), 0.022, INK)
		cyl(head, Vector3(0.07 * side, 0.17, -0.04), 0.028, 0.11, CREAM, Vector3(-15, 0, -14 * side), 0.0)
		box(root, Vector3(0.25 * side, 0.34, -0.03), Vector3(0.28, 0.02, 0.17), dark, Vector3(0, 0, 28 * side))
		ball(root, Vector3(0.1 * side, 0.04, 0.12), 0.055, dark, Vector3(1, 0.6, 1.4))
	cyl(root, Vector3(0, 0.13, -0.38), 0.05, 0.36, hide, Vector3(-78, 0, 0), 0.01)
	return root


# --- Interface pieces --------------------------------------------------------

static func style(bg: Color, border: Color, border_width := 2, radius := 10, margin := 14) -> StyleBoxFlat:
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = bg
	box_style.border_color = border
	box_style.set_border_width_all(border_width)
	box_style.set_corner_radius_all(radius)
	box_style.set_content_margin_all(margin)
	return box_style


static func label(string: String, size: int, color: Color, font: Font = null) -> Label:
	var item := Label.new()
	item.text = string
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	if font:
		item.add_theme_font_override("font", font)
	return item


static func button(string: String, min_size := Vector2(150, 44)) -> Button:
	var item := Button.new()
	item.text = string
	item.custom_minimum_size = min_size
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", CREAM)
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.add_theme_color_override("font_pressed_color", INK)
	item.add_theme_color_override("font_hover_pressed_color", INK)
	item.add_theme_stylebox_override("normal", style(Color(0.09, 0.12, 0.16, 0.95), Color(0.2, 0.45, 0.45), 2, 8, 8))
	item.add_theme_stylebox_override("hover", style(Color(0.13, 0.2, 0.24, 0.98), TEAL, 2, 8, 8))
	item.add_theme_stylebox_override("pressed", style(TEAL, CREAM, 2, 8, 8))
	item.add_theme_stylebox_override("hover_pressed", style(TEAL, CREAM, 2, 8, 8))
	return item
