extends Room
## The Control Room: camera monitors, the power board, the director's desk, and a
## service lift whose doors are new and whose shaft is very much not.

const WALL := Color(0.52, 0.58, 0.66)
const STONE := Color(0.4, 0.39, 0.45)
const STEEL := Color(0.62, 0.66, 0.7)
const VOID := Color(0.02, 0.02, 0.04)
const SCRATCH := Color(0.85, 0.83, 0.75)
const LIFT_GLOW := Color(0.45, 0.95, 0.8)

var _doors: Array[MeshInstance3D] = []
var _button_dots: Array[MeshInstance3D] = []
var _lift_light: OmniLight3D


func build() -> void:
	shot(Vector3(5.9, 5.9, 8.4), Vector3(-0.5, 0.7, -0.5), 44.0)
	mood(Color(0.5, 0.58, 0.8), 0.5, Color(0.9, 0.95, 1.0), 0.6)
	floor_slab(10.0, 7.0, Color(0.18, 0.22, 0.34))
	walls(10.0, 7.0, 3.4, WALL, Color(0.46, 0.52, 0.6))
	spawns = {"default": Vector3(-3.6, 0, -2.1)}
	_exit()
	_monitors()
	_breakers()
	_lift()
	_desk()
	_whiteboard()
	_dressing()
	Kit.lamp(self, Vector3(0, 3.0, 0.5), Color(0.85, 0.92, 1.0), 1.4, 8.0)


func refresh() -> void:
	var powered := Game.flag("lift_on")
	var open := Game.flag("lift_open")
	ease_to(_doors[0], "position:z", -0.75 if open else 0.0)
	ease_to(_doors[1], "position:z", 1.55 if open else 0.8)
	for dot in _button_dots:
		dot.mesh.material = Kit.mat(LIFT_GLOW, 2.5) if powered else Kit.mat(Color(0.2, 0.2, 0.24))
	_lift_light.visible = powered


func entered(_from: String) -> void:
	if not Game.flag("seen_control"):
		Game.set_flag("seen_control")
		Game.say([
			"You are in the Control Room. It hums, the way rooms do when they are pretending everything is fine.",
			"Most of it is office. The lift in the wall is not. The lift is a great deal older than the carpet.",
		])


# --- Set ---------------------------------------------------------------------

func _exit() -> void:
	Kit.box(self, Vector3(-3.6, 1.1, -3.46), Vector3(1.12, 2.2, 0.07), Color(0.2, 0.25, 0.42))
	Kit.box(self, Vector3(-3.6, 2.48, -3.47), Vector3(1.9, 0.32, 0.04), Color(0.95, 0.5, 0.12))
	Kit.text(self, Vector3(-3.6, 2.48, -3.44), "ARRIVALS HALL", 30, Kit.INK)
	spot("exit", "door to Arrivals", Vector3(-3.6, 1.1, -3.3), Vector3(1.2, 2.2, 0.4), Vector3(-3.6, 0, -2.2),
			"The door back to the Arrivals Hall. You can hear the jingle through it.",
			func(_item: String) -> void: main.go_to("lobby"))


func _monitors() -> void:
	var number := 1
	for y in [2.6, 1.9]:
		for x in [-1.5, -0.6, 0.3, 1.2]:
			var lit := number == 5 or number == 6
			Kit.box(self, Vector3(x, y, -3.42), Vector3(0.8, 0.6, 0.12), Color(0.14, 0.15, 0.18))
			if lit:
				Kit.box(self, Vector3(x, y, -3.35), Vector3(0.68, 0.48, 0.02), Color(0.45, 0.75, 0.6), Vector3.ZERO, 1.2)
				Kit.text(self, Vector3(x - 0.16, y + 0.15, -3.33), "CAM %d" % number, 14, Kit.INK)
				Kit.glyph3d(self, Vector3(x, y - 0.4, -3.34), number, 0.24, SCRATCH)
			else:
				Kit.box(self, Vector3(x, y, -3.35), Vector3(0.68, 0.48, 0.02), Color(0.08, 0.1, 0.12))
			number += 1

	Kit.box(self, Vector3(-0.15, 0.45, -2.95), Vector3(3.9, 0.9, 0.9), Color(0.3, 0.35, 0.44))
	Kit.box(self, Vector3(-0.15, 0.95, -2.9), Vector3(3.9, 0.08, 0.8), Color(0.22, 0.26, 0.33), Vector3(12, 0, 0))
	for i in 9:
		var tint: Color = [Color(0.95, 0.3, 0.2), Color(0.95, 0.8, 0.2), Color(0.3, 0.9, 0.5)][i % 3]
		Kit.ball(self, Vector3(-1.7 + i * 0.39, 1.03, -2.75), 0.05, tint, Vector3.ONE, 1.2)

	spot("monitors", "camera monitors", Vector3(-0.15, 1.45, -3.1), Vector3(3.7, 2.9, 0.8), Vector3(-0.15, 0, -1.8),
			_look_monitors)


func _breakers() -> void:
	Kit.box(self, Vector3(3.5, 1.3, -3.36), Vector3(1.3, 1.9, 0.28), Color(0.5, 0.52, 0.56))
	Kit.box(self, Vector3(3.5, 2.0, -3.2), Vector3(1.1, 0.16, 0.02), Color(1.0, 0.82, 0.12))
	Kit.text(self, Vector3(3.5, 2.0, -3.18), "DANGER", 20, Kit.INK)
	for i in 4:
		Kit.box(self, Vector3(3.08 + i * 0.28, 1.25, -3.2), Vector3(0.1, 0.34, 0.06), Kit.INK)
	spot("breakers", "power board", Vector3(3.5, 1.3, -3.25), Vector3(1.3, 1.9, 0.5), Vector3(3.5, 0, -2.2),
			[
				"The main distribution board: four breakers and a gauge. A label says CAPACITY: 5.",
				"Underneath, somebody has added: NOT 6. WE TRIED 6.",
			],
			func(item: String) -> void:
				if item == "":
					main.ui.open_breakers()
				else:
					refuse(item, "power board"))


func _lift() -> void:
	Kit.box(self, Vector3(-4.99, 1.25, 0.4), Vector3(0.02, 2.5, 1.7), VOID)
	Kit.box(self, Vector3(-4.8, 1.4, -0.68), Vector3(0.46, 2.8, 0.46), STONE, Vector3(1.5, 0, 0))
	Kit.box(self, Vector3(-4.8, 1.4, 1.48), Vector3(0.46, 2.8, 0.46), STONE, Vector3(-2, 0, 0))
	Kit.box(self, Vector3(-4.8, 3.0, 0.4), Vector3(0.5, 0.5, 2.7), Color(0.33, 0.32, 0.38), Vector3(1, 0, 0))
	_doors = [
		Kit.box(self, Vector3(-4.94, 1.25, 0.0), Vector3(0.06, 2.5, 0.82), Color(0.8, 0.82, 0.84)),
		Kit.box(self, Vector3(-4.94, 1.25, 0.8), Vector3(0.06, 2.5, 0.82), Color(0.8, 0.82, 0.84)),
	]

	# Nine stone buttons beside the doors.
	Kit.box(self, Vector3(-4.92, 1.35, 2.15), Vector3(0.1, 0.7, 0.6), STONE)
	for row in 3:
		for column in 3:
			_button_dots.append(Kit.ball(self, Vector3(-4.86, 1.55 - row * 0.2, 1.97 + column * 0.18), 0.045, LIFT_GLOW))
	_lift_light = Kit.lamp(self, Vector3(-4.3, 1.6, 0.4), LIFT_GLOW, 1.6, 3.5)

	spot("lift", "service lift", Vector3(-4.7, 1.3, 0.75), Vector3(0.6, 2.6, 3.4), Vector3(-3.7, 0, 0.6),
			[
				"A service lift. The doors are park-issue steel. The frame around them is old stone, and so are the nine buttons beside it.",
				"The park did not dig this shaft. It just put doors on it.",
			],
			_use_lift)


func _desk() -> void:
	Kit.box(self, Vector3(2.4, 0.4, 0.5), Vector3(1.9, 0.8, 0.9), Color(0.5, 0.35, 0.2))
	Kit.cyl(self, Vector3(1.9, 0.87, 0.4), 0.07, 0.14, Kit.CREAM)
	Kit.box(self, Vector3(2.5, 0.81, 0.5), Vector3(0.36, 0.01, 0.46), Kit.CREAM, Vector3(0, 12, 0))
	Kit.box(self, Vector3(3.0, 0.86, 0.75), Vector3(0.5, 0.1, 0.06), Kit.INK)
	spot("desk", "director's desk", Vector3(2.4, 0.5, 0.5), Vector3(1.9, 1.0, 0.9), Vector3(1.0, 0, 0.5),
			func() -> void:
				Game.award("read_sign")
				Game.note("Director's memo blames the noises on 'the cave settling'.")
				Game.say([
					"The director's desk. A mug says WORLD'S OKAYEST DIRECTOR.",
					"An unsent memo: 'RE: THE NOISES. It is just the cave settling. Caves settle. Please stop asking what it is settling on.'",
					"A sticky note: 'Inspector arrives Thursday. Hide the' and then the rest has been torn off, by something with a wide bite.",
				]))


func _whiteboard() -> void:
	Kit.box(self, Vector3(-4.97, 1.8, -2.2), Vector3(0.04, 1.1, 1.6), Color(0.96, 0.96, 0.94))
	Kit.text(self, Vector3(-4.94, 1.95, -2.2), "DAYS UNTIL\nOPENING: 1", 30, Kit.INK, Vector3(0, 90, 0))
	Kit.text(self, Vector3(-4.94, 1.45, -2.2), ":)", 40, Color(0.9, 0.2, 0.15), Vector3(0, 90, -90))
	spot("whiteboard", "whiteboard", Vector3(-4.85, 1.8, -2.2), Vector3(0.3, 1.1, 1.6), Vector3(-3.9, 0, -1.6),
			func() -> void:
				Game.award("read_sign")
				Game.say("A whiteboard. DAYS UNTIL OPENING: 1. Someone has drawn a smiley face. Someone else has drawn teeth on it."))


func _dressing() -> void:
	# Rug, a chair that left in a hurry, hazard paint at the lift, and a clock.
	Kit.box(self, Vector3(2.3, 0.006, 0.5), Vector3(3.4, 0.012, 2.6), Color(0.3, 0.2, 0.3))
	Kit.box(self, Vector3(2.3, 0.008, 0.5), Vector3(3.0, 0.014, 2.2), Color(0.42, 0.26, 0.34))

	var chair := Node3D.new()
	chair.position = Vector3(3.3, 0.28, -0.75)
	chair.rotation_degrees = Vector3(0, 40, 90)
	add_child(chair)
	Kit.box(chair, Vector3(0, 0.25, 0), Vector3(0.55, 0.1, 0.55), Color(0.16, 0.18, 0.24))
	Kit.box(chair, Vector3(0, 0.62, -0.25), Vector3(0.55, 0.66, 0.08), Color(0.16, 0.18, 0.24))
	Kit.cyl(chair, Vector3(0, 0.0, 0), 0.04, 0.45, STEEL)
	Kit.cyl(chair, Vector3(0, -0.24, 0), 0.3, 0.04, STEEL)
	spot("chair", "office chair", Vector3(3.3, 0.35, -0.75), Vector3(1.0, 0.7, 0.9), Vector3(3.6, 0, 0.9),
			"The director's chair, on its side. It is still very slightly spinning.")

	for i in 7:
		var paint := Color(1.0, 0.82, 0.12) if i % 2 == 0 else Kit.INK
		Kit.box(self, Vector3(-4.35, 0.006, -0.5 + i * 0.3), Vector3(0.5, 0.012, 0.3), paint)
	Kit.box(self, Vector3(-4.9, 1.25, 0.4), Vector3(0.07, 2.5, 0.03), Kit.INK)

	Kit.cyl(self, Vector3(-2.6, 2.75, -3.46), 0.3, 0.06, Kit.CREAM, Vector3(90, 0, 0))
	Kit.box(self, Vector3(-2.6, 2.83, -3.42), Vector3(0.03, 0.2, 0.02), Kit.INK)
	Kit.box(self, Vector3(-2.52, 2.75, -3.42), Vector3(0.18, 0.03, 0.02), Kit.INK)
	spot("clock", "wall clock", Vector3(-2.6, 2.75, -3.4), Vector3(0.7, 0.7, 0.2), Vector3(-2.4, 0, -2.2),
			"The clock stopped at a quarter past twelve. The second hand is still trying. It twitches, and falls back, and twitches.")

	Kit.box(self, Vector3(-4.94, 2.1, 2.15), Vector3(0.04, 0.26, 0.7), Color(0.95, 0.5, 0.12))
	Kit.text(self, Vector3(-4.91, 2.1, 2.15), "STAFF LIFT", 22, Kit.INK, Vector3(0, 90, 0))


# --- Story -------------------------------------------------------------------

func _look_monitors() -> void:
	Game.note("Scratched under the monitors: CAM 5 has an upturned V. CAM 6 has an upturned V and one stroke.")
	Game.say([
		"A wall of monitors. Most show static. Two are working.",
		"CAM 5 shows an empty walkway. CAM 6 shows the same walkway from the other end, with something just leaving it.",
		"Marks have been scratched under each working screen. Under CAM 5: an upturned V. Under CAM 6: an upturned V, then one stroke.",
		"The scratches are on the inside of the plastic.",
	])


func _use_lift(item: String) -> void:
	if item != "":
		refuse(item, "lift")
	elif Game.flag("lift_open"):
		main.finish_chapter()
	elif Game.flag("lift_on"):
		main.ui.open_keypad()
	else:
		Sfx.play("error")
		Game.say("You press a stone button. Nothing. The lift has no power, which is the safest it will be all night.")
