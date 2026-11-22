extends Room
## The Hatchery: three incubator bays cut into the rock, a viewing window onto
## Enclosure A, the ranger's logbook, and a hatchling with a stolen staff pass.

const ROCK := Color(0.36, 0.33, 0.4)
const CARVED := Color(0.8, 0.77, 0.7)
const STEEL := Color(0.5, 0.56, 0.6)
const VOID := Color(0.02, 0.03, 0.05)
const GLASS := Color(0.7, 0.92, 1.0, 0.22)
const HEAT := Color(1.0, 0.55, 0.2)

const BAYS := [
	{"x": -3.8, "species": "MAGPIE WYRM", "days": 6, "egg": Color(0.4, 0.3, 0.6)},
	{"x": -0.8, "species": "EMBER DRAKE", "days": 4, "egg": Color(0.85, 0.3, 0.15)},
	{"x": 2.2, "species": "ECHO WYVERN", "days": 8, "egg": Color(0.55, 0.75, 0.6)},
]

var _bulbs: Array[MeshInstance3D] = []
var _heat_lights: Array[OmniLight3D] = []
var _ember_egg: MeshInstance3D
var _eyes: Node3D
var _hatchling: Node3D
var _held_pass: MeshInstance3D
var _held_bell: Node3D
var _time := 0.0


func build() -> void:
	shot(Vector3(6.65, 6.45, 9.25), Vector3(-0.5, 0.7, -0.7), 44.0)
	mood(Color(0.5, 0.5, 0.75), 0.5, Color(1.0, 0.85, 0.7), 0.55)
	floor_slab(12.0, 8.0, Color(0.27, 0.29, 0.34))
	walls(12.0, 8.0, 3.6, ROCK, Color(0.74, 0.7, 0.62))
	spawns = {"default": Vector3(-4.6, 0, 2.5)}
	for i in BAYS.size():
		_bay(i)
	_window()
	_logbook()
	_locker_and_hatchling()
	_exit()


func refresh() -> void:
	var warm := not Game.flag("heat_off")
	for bulb in _bulbs:
		bulb.mesh.material = Kit.mat(HEAT, 2.5) if warm else Kit.mat(Color(0.3, 0.25, 0.22))
	for light in _heat_lights:
		light.visible = warm
	_eyes.visible = not Game.flag("fences_off")
	var traded := Game.flag("pass_taken")
	_held_pass.visible = not traded
	_held_bell.visible = traded


func entered(_from: String) -> void:
	if not Game.flag("seen_hatchery"):
		Game.set_flag("seen_hatchery")
		Game.say([
			"You are in the Hatchery. It is warmer in here, and it smells of straw and hot pennies.",
			"PA: Quiet, please! Future legends are sleeping.",
			"Three bays are cut into the rock. Something small is watching you from on top of a locker.",
		])


func _process(delta: float) -> void:
	_time += delta
	# The hatchling fidgets, the unhatched egg rocks, and the eyes in the dark blink.
	_hatchling.position.y = 2.0 + absf(sin(_time * 2.2)) * 0.03
	# It watches the inspector, head cocked, and flutters and wags when it feels like it.
	var head: Node3D = _hatchling.get_node("Head")
	var watched: Vector3 = _hatchling.to_local(main.player.global_position + Vector3(0, 1.4, 0))
	var aim := Vector3(
			clampf(-atan2(watched.y - 0.42, Vector2(watched.x, watched.z).length()), -0.3, 0.7),
			clampf(atan2(watched.x, watched.z), -1.2, 1.2),
			sin(_time * 1.3) * 0.2)
	head.rotation = head.rotation.lerp(aim, minf(1.0, delta * 6.0))
	head.get_node("Eyes").scale.y = 0.1 if fmod(_time, 2.9) < 0.12 else 1.0
	var flutter := sin(_time * 34.0) * 0.5 if fmod(_time, 4.3) < 0.45 else 0.0
	_hatchling.get_node("WingL").rotation.z = deg_to_rad(28.0) + flutter
	_hatchling.get_node("WingR").rotation.z = deg_to_rad(-28.0) - flutter
	_hatchling.get_node("Tail").rotation.y = sin(_time * 3.0) * 0.35
	if not Game.flag("heat_off"):
		_ember_egg.rotation.z = sin(_time * 5.0) * 0.12 if fmod(_time, 5.0) < 0.9 else 0.0
	_eyes.scale.y = 0.1 if fmod(_time, 3.7) < 0.14 else 1.0


# --- Set ---------------------------------------------------------------------

func _bay(index: int) -> void:
	var bay: Dictionary = BAYS[index]
	var x: float = bay["x"]
	var number := index + 1

	Kit.box(self, Vector3(x, 1.4, -3.97), Vector3(2.3, 2.8, 0.06), Color(0.27, 0.25, 0.32))
	Kit.glyph3d(self, Vector3(x, 3.15, -3.95), number, 0.6, CARVED)
	Kit.cyl(self, Vector3(x, 0.35, -3.1), 0.62, 0.7, STEEL)
	Kit.cyl(self, Vector3(x, 0.74, -3.1), 0.56, 0.1, Color(0.85, 0.72, 0.35))
	Kit.box(self, Vector3(x + 0.25, 0.42, -2.47), Vector3(0.36, 0.26, 0.02), Kit.CREAM)
	Kit.text(self, Vector3(x + 0.25, 0.42, -2.45), "%d DAYS" % bay["days"], 14, Kit.INK)

	# Heat lamp.
	Kit.cyl(self, Vector3(x, 2.75, -3.1), 0.02, 0.9, Kit.INK)
	Kit.cyl(self, Vector3(x, 2.3, -3.1), 0.34, 0.26, Color(0.25, 0.26, 0.3), Vector3.ZERO, 0.08)
	_bulbs.append(Kit.ball(self, Vector3(x, 2.17, -3.1), 0.1, HEAT, Vector3.ONE, 2.5))
	_heat_lights.append(Kit.lamp(self, Vector3(x, 1.9, -2.9), HEAT, 1.8, 3.2))

	var egg_color: Color = bay["egg"]
	match number:
		1:
			# Hatched: two neat halves, under an intact dome.
			Kit.ball(self, Vector3(x - 0.18, 0.9, -3.1), 0.24, egg_color, Vector3(1, 0.7, 1))
			Kit.ball(self, Vector3(x + 0.22, 0.88, -3.0), 0.22, egg_color, Vector3(1, 0.6, 1))
			Kit.ball(self, Vector3(x, 0.95, -3.1), 0.6, GLASS)
		2:
			_ember_egg = Kit.ball(self, Vector3(x, 1.12, -3.1), 0.27, egg_color, Vector3(1, 1.35, 1))
			Kit.ball(self, Vector3(x, 0.95, -3.1), 0.6, GLASS)
		3:
			# Broken out: shell on the nest, glass all over the floor in front.
			Kit.ball(self, Vector3(x - 0.1, 0.88, -3.15), 0.22, egg_color, Vector3(1, 0.6, 1))
			for i in 7:
				Kit.box(self, Vector3(x - 0.7 + i * 0.24, 0.02, -2.1 + sin(i * 2.3) * 0.25),
						Vector3(0.16, 0.02, 0.1), Color(0.7, 0.92, 1.0, 0.5), Vector3(0, i * 47, 0))

	spot("bay%d" % number, "bay %s" % ["one", "two", "three"][index], Vector3(x, 1.0, -3.1), Vector3(1.4, 2.0, 1.4),
			Vector3(x, 0, -1.6), _look_bay.bind(number))


func _window() -> void:
	Kit.box(self, Vector3(-5.98, 1.75, -1.0), Vector3(0.03, 1.6, 3.3), VOID)
	for z in [-2.72, 0.72]:
		Kit.box(self, Vector3(-5.95, 1.75, z), Vector3(0.08, 1.76, 0.14), STEEL)
	for y in [0.92, 2.58]:
		Kit.box(self, Vector3(-5.95, y, -1.0), Vector3(0.08, 0.14, 3.58), STEEL)
	Kit.text(self, Vector3(-5.93, 3.0, -1.0), "ENCLOSURE A", 44, Kit.INK, Vector3(0, 90, 0))
	Kit.box(self, Vector3(-5.96, 0.6, -1.0), Vector3(0.03, 0.26, 1.9), Kit.CREAM)
	Kit.text(self, Vector3(-5.93, 0.6, -1.0), "PLEASE DO NOT TAP THE GLASS", 18, Kit.INK, Vector3(0, 90, 0))

	_eyes = Node3D.new()
	_eyes.position = Vector3(-5.94, 1.9, -0.3)
	add_child(_eyes)
	for z in [-0.13, 0.13]:
		Kit.ball(_eyes, Vector3(0, 0, z), 0.07, Color(1.0, 0.75, 0.1), Vector3(0.3, 0.6, 1), 3.0)

	spot("window", "viewing window", Vector3(-5.85, 1.6, -1.0), Vector3(0.3, 2.3, 3.4), Vector3(-4.8, 0, -1.0),
			_look_window, _use_window)


func _logbook() -> void:
	Kit.box(self, Vector3(0.8, 0.5, 0.8), Vector3(0.6, 1.0, 0.5), Color(0.5, 0.35, 0.2))
	Kit.box(self, Vector3(0.8, 1.06, 0.8), Vector3(0.66, 0.05, 0.5), Color(0.4, 0.27, 0.15), Vector3(0, 0, -14))
	Kit.box(self, Vector3(0.8, 1.1, 0.8), Vector3(0.5, 0.04, 0.38), Kit.CREAM, Vector3(0, 0, -14))
	spot("logbook", "ranger's logbook", Vector3(0.8, 0.6, 0.8), Vector3(0.7, 1.3, 0.6), Vector3(2.0, 0, 0.8),
			_read_logbook)


func _locker_and_hatchling() -> void:
	Kit.box(self, Vector3(4.9, 1.0, -3.4), Vector3(1.1, 2.0, 0.9), Color(0.33, 0.45, 0.38))
	Kit.box(self, Vector3(4.9, 1.0, -2.94), Vector3(0.02, 1.8, 0.02), Kit.INK)
	Kit.text(self, Vector3(4.9, 1.6, -2.93), "FEED", 30, Kit.CREAM)
	spot("locker", "feed locker", Vector3(4.9, 0.95, -3.4), Vector3(1.1, 1.9, 0.9), Vector3(4.6, 0, -2.1),
			[
				"The feed locker. The label says FEED.",
				"Under that, someone has added a list of things that are not feed: fingers, lanyards, the work experience boy's phone.",
			])

	_hatchling = Kit.hatchling(self, Vector3(4.9, 2.0, -3.3))
	_hatchling.rotation_degrees.y = 25.0
	_hatchling.scale = Vector3.ONE * 1.5
	_held_pass = Kit.box(_hatchling, Vector3(0, 0.36, 0.42), Vector3(0.16, 0.1, 0.01), Color(0.95, 0.97, 1.0), Vector3(0, 0, 12), 0.8)
	_held_bell = Node3D.new()
	_held_bell.position = Vector3(0, 0.3, 0.42)
	_hatchling.add_child(_held_bell)
	Kit.ball(_held_bell, Vector3.ZERO, 0.08, Color(0.92, 0.72, 0.2), Vector3(1, 0.8, 1), 0.4)

	spot("hatchling", "hatchling", Vector3(4.9, 2.45, -3.3), Vector3(0.9, 0.9, 0.9), Vector3(4.6, 0, -2.1),
			_look_hatchling, _use_hatchling)


func _exit() -> void:
	Kit.box(self, Vector3(-5.95, 1.1, 2.5), Vector3(0.07, 2.2, 1.12), Color(0.2, 0.25, 0.42))
	Kit.box(self, Vector3(-5.96, 2.5, 2.5), Vector3(0.04, 0.34, 2.0), Color(0.95, 0.5, 0.12))
	Kit.text(self, Vector3(-5.93, 2.5, 2.5), "EXIT VIA GIFT SHOP", 30, Kit.INK, Vector3(0, 90, 0))
	spot("exit", "way back to Arrivals", Vector3(-5.8, 1.1, 2.5), Vector3(0.4, 2.2, 1.2), Vector3(-4.8, 0, 2.5),
			"EXIT VIA GIFT SHOP. There is no gift shop yet. The sign is aspirational. The door leads back to the Arrivals Hall.",
			func(_item: String) -> void: main.go_to("lobby"))


# --- Story -------------------------------------------------------------------

func _look_bay(number: int) -> void:
	var bay: Dictionary = BAYS[number - 1]
	var marks: String = ["a single claw stroke", "two claw strokes", "three claw strokes"][number - 1]
	Game.note("Bay %d (%s): incubation %d days. Carved above it: %s." % [number, bay["species"].capitalize(), bay["days"], marks])
	match number:
		1:
			Game.say([
				"BAY ONE: MAGPIE WYRM. The shell lies in two neat halves. The inside of the glass is covered in small scratches, all of them near the catch.",
				"The tag reads: INCUBATION, 6 DAYS.",
				"Cut into the rock above the bay is a single claw stroke. The carving is much older than the bay.",
			])
		2:
			var egg := "The egg is whole, and warm, and every so often it rocks towards you."
			if Game.flag("heat_off"):
				egg = "The egg is whole. With the lamp off it has stopped rocking. You feel judged."
			Game.say([
				"BAY TWO: EMBER DRAKE. " + egg,
				"The tag reads: INCUBATION, 4 DAYS. Under that, in pen: ANY DAY NOW. Under that, in different pen: please.",
				"Two claw strokes are carved above this one.",
			])
		3:
			Game.say([
				"BAY THREE: ECHO WYVERN. The dome is broken. All of the glass is on the outside.",
				"The tag reads: INCUBATION, 8 DAYS.",
				"Three strokes above it. Whoever carved these numbered the alcoves long before there was anything to put in them.",
			])


func _look_window() -> void:
	Game.award("read_sign")
	if Game.flag("fences_off"):
		Game.say([
			"The window onto Enclosure A. The gate at the back is standing open.",
			"The eyes have gone. This is not the improvement it sounds like.",
		])
	else:
		Game.say([
			"A viewing window onto Enclosure A. It is dark in there.",
			"The dark has eyes. The eyes are doing their best to look like not eyes.",
		])


func _use_window(item: String) -> void:
	if item != "":
		refuse(item, "window")
		return
	Sfx.play("tick", -2.0)
	Game.award("tapped")
	if Game.flag("fences_off"):
		Game.say("You tap the glass. Nothing taps back. You find that you miss it.")
	else:
		Game.react("startle")
		Game.say([
			"You tap the glass. You are an inspector. It is practically the job.",
			"Something taps back. Same rhythm. Slightly harder.",
		])


func _read_logbook() -> void:
	Game.note("Ranger's log: the lift code is the incubation days, in bay order.")
	Game.note("Ranger's log: the lift buttons use the same marks as the carvings over the bays.")
	Game.say([
		"The hatchery logbook. Ranger Dev's handwriting starts tidy and gets less so.",
		"'Day 6. Bay One hatched. It stole my watch. I am so proud.'",
		"'Day 8. Bay Three hatched overnight. It was saying my name when I came in. I never told it my name.'",
		"'Head office changed the lift code again: incubation days, bay order. They said don't write it down, so I haven't. This doesn't count.'",
		"'The lift buttons aren't even numbers. They're the same scratches as over the bays. We didn't put those there. Nobody will tell me who did.'",
		"The last entry just says: 'It does my voice better than I do.'",
	])


func _look_hatchling() -> void:
	if Game.flag("pass_taken"):
		Game.say("The hatchling polishes the bell on its own stomach, then holds it up to check its reflection. It approves.")
	else:
		Game.say([
			"A hatchling the colour of a bruise, about the size of a cat. It is holding a staff pass, because the staff pass is shiny.",
			"It looks at your hard hat, and then at your clipboard, and is not impressed by either.",
		])


func _use_hatchling(item: String) -> void:
	if Game.flag("pass_taken"):
		Sfx.play("bell", -12.0)
		Game.say("The hatchling rings the bell at you. It has no intention of ever stopping.")
	elif item == "bell":
		Sfx.play("bell")
		Game.remove_item("bell")
		Game.add_item("pass")
		Game.set_flag("pass_taken")
		Game.award("trade")
		Game.say([
			"You hold up the bell. The hatchling's eyes go as round as coins.",
			"It drops the staff pass, takes the bell in both claws, and rings it. Then it rings it again.",
			"It has found its calling. You have found a staff pass.",
		])
	elif item == "picker":
		Game.say("You reach up with the litter picker. The hatchling bites the end, thoughtfully, and lets go. It was only checking.")
	elif item == "":
		Game.react("startle")
		Game.say([
			"You hold out a hand. The hatchling clutches the staff pass to its chest and hisses like a small kettle.",
			"It will not come down for nothing. It might come down for something better.",
		])
	else:
		refuse(item, "hatchling")
