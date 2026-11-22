extends Room
## The Arrivals Hall: ticket desk, mascot statue, a turnstile set into an old stone
## arch (to the Hatchery) and a staff door (to the Control Room).

const WALL := Color(0.87, 0.81, 0.68)
const BRAND_TEAL := Color(0.16, 0.5, 0.5)
const BRAND_ORANGE := Color(0.95, 0.5, 0.12)
const STONE := Color(0.44, 0.43, 0.48)
const STEEL := Color(0.62, 0.66, 0.7)
const VOID := Color(0.02, 0.02, 0.04)
const RED := Color(0.95, 0.2, 0.15)
const GREEN := Color(0.3, 0.95, 0.4)

var _gate: Node3D
var _gate_light: MeshInstance3D
var _door: MeshInstance3D
var _door_led: MeshInstance3D
var _picker: Node3D
var _bell: Node3D


func build() -> void:
	shot(Vector3(6.65, 6.6, 9.75), Vector3(-0.4, 0.7, -0.8), 44.0)
	mood(Color(0.6, 0.66, 0.85), 0.6, Color(1.0, 0.93, 0.8), 0.8)
	floor_slab(12.0, 9.0, Color(0.2, 0.33, 0.36))
	walls(12.0, 9.0, 3.6, WALL, Color(0.8, 0.74, 0.62))
	spawns = {
		"default": Vector3(1.6, 0, 2.4),
		"hatchery": Vector3(2.5, 0, -3.0),
		"control": Vector3(-4.7, 0, -2.2),
	}
	_dressing()
	_arch_and_turnstile()
	_ticket_desk()
	_cinders()
	_staff_door()
	_small_props()


func refresh() -> void:
	var gate_open := Game.flag("turnstile_open")
	ease_to(_gate, "rotation_degrees:y", 80.0 if gate_open else 0.0)
	_gate_light.mesh.material = Kit.mat(GREEN if gate_open else RED, 2.0)

	var door_open := Game.flag("staff_door_open")
	ease_to(_door, "position:z", -3.35 if door_open else -2.2)
	_door_led.mesh.material = Kit.mat(GREEN if door_open else RED, 2.0)

	_picker.visible = not Game.flag("picker_taken")
	hotspots["picker"].set_active(_picker.visible)
	_bell.visible = not Game.flag("bell_taken")
	hotspots["bell"].set_active(_bell.visible)


# --- Set ---------------------------------------------------------------------

func _dressing() -> void:
	# Painted stripe along both walls, and a trail of dragon footprints to the turnstile.
	Kit.box(self, Vector3(0, 1.05, -4.49), Vector3(12, 0.14, 0.02), BRAND_TEAL)
	Kit.box(self, Vector3(-5.99, 1.05, 0), Vector3(0.02, 0.14, 9), BRAND_TEAL)
	for i in 8:
		var side := 0.2 if i % 2 == 0 else -0.2
		Kit.cyl(self, Vector3(2.5 + side, 0.006, 2.9 - i * 0.78), 0.15, 0.012, Color(0.26, 0.42, 0.44))

	Kit.box(self, Vector3(-2.4, 3.0, -4.47), Vector3(6.6, 1.0, 0.05), BRAND_ORANGE)
	Kit.text(self, Vector3(-2.4, 3.1, -4.43), "WYRMHOLLOW", 120, Kit.CREAM)
	Kit.text(self, Vector3(-2.4, 2.68, -4.43), "WHERE LEGENDS ARE BRED", 36, Kit.INK)
	spot("banner", "welcome banner", Vector3(-2.4, 3.0, -4.4), Vector3(6.6, 1.0, 0.2), Vector3(-1.0, 0, -1.2),
			func() -> void:
				Game.award("read_sign")
				Game.say([
					"WYRMHOLLOW: WHERE LEGENDS ARE BRED.",
					"Somebody was paid to write that. Somebody else signed it off. Neither of them is here tonight.",
				]))

	Kit.lamp(self, Vector3(-1.5, 3.2, 0.5), Color(1.0, 0.9, 0.75), 1.6, 9.0)
	Kit.lamp(self, Vector3(2.5, 2.0, -3.6), Color(0.5, 0.9, 0.85), 1.2, 4.0)


func _arch_and_turnstile() -> void:
	Kit.box(self, Vector3(2.5, 1.25, -4.46), Vector3(1.7, 2.5, 0.05), VOID)
	Kit.box(self, Vector3(1.45, 1.3, -4.28), Vector3(0.55, 2.6, 0.5), STONE, Vector3(0, 0, 1.5))
	Kit.box(self, Vector3(3.55, 1.3, -4.28), Vector3(0.55, 2.6, 0.5), STONE, Vector3(0, 0, -2))
	Kit.box(self, Vector3(2.5, 2.8, -4.28), Vector3(2.9, 0.55, 0.56), Color(0.37, 0.36, 0.42), Vector3(0, 0, 1))

	# The old carving on the left pillar: a five-clawed print and the glyph for five.
	var carved := Color(0.2, 0.19, 0.24)
	Kit.ball(self, Vector3(1.45, 1.62, -4.03), 0.09, carved, Vector3(1, 1, 0.2))
	for i in 5:
		var angle := deg_to_rad(-50.0 + i * 25.0)
		Kit.box(self, Vector3(1.45 + sin(angle) * 0.17, 1.62 + cos(angle) * 0.17, -4.03),
				Vector3(0.035, 0.12, 0.02), carved, Vector3(0, 0, -rad_to_deg(angle)))
	Kit.glyph3d(self, Vector3(1.45, 1.2, -4.03), 5, 0.42, carved)

	Kit.cyl(self, Vector3(1.9, 0.5, -3.95), 0.09, 1.0, STEEL)
	_gate = Node3D.new()
	_gate.position = Vector3(1.9, 0.92, -3.95)
	add_child(_gate)
	Kit.cyl(_gate, Vector3(0.58, 0, 0), 0.045, 1.16, STEEL, Vector3(0, 0, 90))
	Kit.cyl(_gate, Vector3(0.58, -0.3, 0), 0.045, 1.16, STEEL, Vector3(0, 0, 90))

	Kit.box(self, Vector3(3.2, 0.6, -3.95), Vector3(0.32, 1.2, 0.32), BRAND_TEAL)
	Kit.box(self, Vector3(3.2, 1.0, -3.78), Vector3(0.14, 0.03, 0.02), VOID)
	_gate_light = Kit.ball(self, Vector3(3.2, 1.27, -3.95), 0.07, RED, Vector3.ONE, 2.0)

	spot("carving", "old carving", Vector3(1.45, 1.4, -3.98), Vector3(0.55, 1.1, 0.16), Vector3(1.5, 0, -3.1),
			_look_carving)
	spot("turnstile", "turnstile", Vector3(2.6, 1.0, -4.0), Vector3(1.6, 2.0, 0.5), Vector3(2.5, 0, -3.1),
			"A turnstile set into an arch of old stone. The arch was here first. The park was built around it, the way you'd build a kitchen around a stain.",
			_use_turnstile)


func _ticket_desk() -> void:
	Kit.box(self, Vector3(-2.2, 0.5, -2.9), Vector3(2.6, 1.0, 0.9), BRAND_TEAL)
	Kit.box(self, Vector3(-2.2, 1.02, -2.9), Vector3(2.7, 0.06, 1.0), BRAND_ORANGE)
	Kit.box(self, Vector3(-2.9, 1.2, -2.8), Vector3(0.7, 0.3, 0.04), Kit.CREAM, Vector3(-12, 0, 0))
	Kit.text(self, Vector3(-2.9, 1.2, -2.77), "BACK IN\n5 MINUTES", 16, Kit.INK, Vector3(-12, 0, 0))
	Kit.text(self, Vector3(-2.2, 0.55, -2.44), "TICKETS", 44, Kit.CREAM)

	_bell = Node3D.new()
	_bell.position = Vector3(-1.7, 1.05, -2.75)
	add_child(_bell)
	var brass := Color(0.92, 0.72, 0.2)
	Kit.cyl(_bell, Vector3(0, 0.015, 0), 0.13, 0.03, Color(0.3, 0.22, 0.12))
	Kit.ball(_bell, Vector3(0, 0.04, 0), 0.11, brass, Vector3(1, 0.8, 1))
	Kit.cyl(_bell, Vector3(0, 0.14, 0), 0.02, 0.05, brass)

	spot("desk", "ticket desk", Vector3(-2.2, 0.5, -2.9), Vector3(2.6, 1.0, 0.9), Vector3(-2.7, 0, -1.7),
			func() -> void:
				Game.award("read_sign")
				Game.say([
					"The ticket desk. A sign says BACK IN 5 MINUTES.",
					"The dust on the sign says otherwise.",
				]))
	spot("bell", "service bell", Vector3(-1.7, 1.15, -2.75), Vector3(0.36, 0.3, 0.36), Vector3(-1.7, 0, -1.7),
			"A brass service bell. RING FOR SERVICE. It has been polished to a shine. It is the only thing in here anyone has looked after.",
			_use_bell)


func _cinders() -> void:
	var statue := Node3D.new()
	statue.position = Vector3(4.6, 0, -2.9)
	statue.rotation_degrees.y = -28.0
	add_child(statue)
	var green := Color(0.3, 0.64, 0.33)
	var belly := Color(0.94, 0.87, 0.6)
	Kit.cyl(statue, Vector3(0, 0.12, 0), 0.95, 0.24, Color(0.3, 0.28, 0.32))
	Kit.ball(statue, Vector3(0, 1.0, 0), 0.68, green, Vector3(1, 1.15, 0.95))
	Kit.ball(statue, Vector3(0, 0.92, 0.36), 0.46, belly, Vector3(1, 1.1, 0.8))
	Kit.ball(statue, Vector3(0, 2.0, 0.18), 0.46, green)
	Kit.box(statue, Vector3(0, 1.9, 0.62), Vector3(0.5, 0.34, 0.5), green)
	Kit.box(statue, Vector3(0, 1.82, 0.83), Vector3(0.36, 0.14, 0.12), VOID)
	Kit.cyl(statue, Vector3(-0.95, 0.75, -0.2), 0.09, 1.0, green, Vector3(0, 0, 65))
	Kit.ball(statue, Vector3(-1.42, 0.97, -0.2), 0.15, RED)
	for side in [-1.0, 1.0]:
		Kit.ball(statue, Vector3(0.2 * side, 2.17, 0.53), 0.13, Color.WHITE)
		Kit.ball(statue, Vector3(0.2 * side, 2.17, 0.64), 0.06, Kit.INK)
		Kit.cyl(statue, Vector3(0.24 * side, 2.5, 0.05), 0.08, 0.32, belly, Vector3(0, 0, -12 * side), 0.0)
		Kit.box(statue, Vector3(0.82 * side, 1.45, -0.25), Vector3(0.75, 0.55, 0.06), Color(0.22, 0.5, 0.26), Vector3(0, 20 * side, 25 * side))
		Kit.ball(statue, Vector3(0.5 * side, 1.15, 0.45), 0.16, green)
		Kit.ball(statue, Vector3(0.36 * side, 0.34, 0.5), 0.22, green, Vector3(1, 0.6, 1.3))
	Kit.box(statue, Vector3(0, 0.44, 1.0), Vector3(1.4, 0.5, 0.05), Kit.CREAM, Vector3(-15, 0, 0))
	Kit.text(statue, Vector3(0, 0.45, 1.04), "PULL MY TAIL\nFOR A SOUVENIR TOKEN!", 22, Kit.INK, Vector3(-15, 0, 0))

	spot("cinders", "Cinders the Friendly Wyrm", Vector3(4.6, 1.35, -2.9), Vector3(2.0, 2.7, 2.0), Vector3(3.9, 0, -1.0),
			func() -> void:
				Game.award("read_sign")
				Game.say([
					"CINDERS THE FRIENDLY WYRM, says the plaque. PULL MY TAIL FOR A SOUVENIR TOKEN!",
					"Its eyes follow you around the room. They are painted on. They follow you anyway.",
				]),
			_use_cinders)


func _staff_door() -> void:
	Kit.box(self, Vector3(-5.98, 1.1, -2.2), Vector3(0.03, 2.2, 1.1), VOID)
	_door = Kit.box(self, Vector3(-5.95, 1.1, -2.2), Vector3(0.07, 2.2, 1.12), Color(0.2, 0.25, 0.42))
	Kit.box(self, Vector3(-5.96, 2.5, -2.2), Vector3(0.04, 0.34, 1.3), BRAND_ORANGE)
	Kit.text(self, Vector3(-5.93, 2.5, -2.2), "STAFF ONLY", 34, Kit.INK, Vector3(0, 90, 0))
	Kit.box(self, Vector3(-5.94, 1.2, -1.42), Vector3(0.08, 0.3, 0.2), Color(0.25, 0.26, 0.3))
	_door_led = Kit.ball(self, Vector3(-5.89, 1.28, -1.42), 0.035, RED, Vector3.ONE, 2.0)

	spot("staff_door", "staff door", Vector3(-5.8, 1.1, -2.1), Vector3(0.4, 2.2, 1.6), Vector3(-4.8, 0, -2.2),
			"STAFF ONLY. A card reader glows beside the door. It wants a staff pass, and it is not going to be reasonable about it.",
			_use_staff_door)


func _small_props() -> void:
	# Incident counter.
	Kit.box(self, Vector3(-4.6, 1.95, -4.47), Vector3(2.0, 1.0, 0.05), Color(0.95, 0.95, 0.92))
	Kit.text(self, Vector3(-4.95, 1.98, -4.43), "DAYS\nWITHOUT\nINCIDENT", 24, Kit.INK)
	Kit.box(self, Vector3(-4.0, 1.95, -4.43), Vector3(0.6, 0.76, 0.04), Kit.CREAM)
	Kit.text(self, Vector3(-4.0, 1.95, -4.4), "0", 110, RED)
	Kit.box(self, Vector3(-4.6, 0.12, -4.2), Vector3(0.6, 0.24, 0.45), Color(0.6, 0.45, 0.28))
	spot("incident_sign", "incident counter", Vector3(-4.6, 1.95, -4.4), Vector3(2.0, 1.0, 0.2), Vector3(-4.5, 0, -2.5),
			func() -> void:
				Game.award("read_sign")
				Game.note("Incident counter reads zero. They have nearly run out of zeros.")
				Game.say([
					"DAYS WITHOUT INCIDENT: 0.",
					"Underneath is a box of spare zeros. It is nearly empty.",
				]))

	# Leaflets.
	Kit.box(self, Vector3(-5.6, 0.6, 1.4), Vector3(0.4, 1.2, 1.0), Color(0.5, 0.35, 0.2))
	for row in 3:
		for column in 3:
			var tint := BRAND_ORANGE if (row + column) % 2 == 0 else BRAND_TEAL
			Kit.box(self, Vector3(-5.38, 0.4 + row * 0.32, 1.1 + column * 0.3), Vector3(0.03, 0.26, 0.2), tint, Vector3(0, 0, -12))
	spot("leaflets", "leaflet stand", Vector3(-5.6, 0.6, 1.4), Vector3(0.5, 1.2, 1.0), Vector3(-4.7, 0, 1.4),
			_use_leaflets)

	# Bin and litter picker.
	Kit.cyl(self, Vector3(0.1, 0.4, -4.0), 0.3, 0.8, Color(0.2, 0.5, 0.3))
	Kit.cyl(self, Vector3(0.1, 0.82, -4.0), 0.32, 0.06, Color(0.15, 0.4, 0.22))
	Kit.box(self, Vector3(0.1, 0.6, -3.69), Vector3(0.34, 0.12, 0.03), VOID)
	spot("bin", "litter bin", Vector3(0.1, 0.45, -4.0), Vector3(0.64, 0.9, 0.64), Vector3(0.1, 0, -3.0),
			func() -> void:
				Game.award("read_sign")
				Game.say("A bin shaped like a dragon's mouth. FEED ME LITTER, says the sign. It is the only thing in this park that has been fed on schedule."))

	_picker = Node3D.new()
	_picker.position = Vector3(0.85, 0, -4.25)
	add_child(_picker)
	Kit.cyl(_picker, Vector3(0, 0.6, 0), 0.025, 1.2, STEEL, Vector3(8, 0, -6))
	Kit.box(_picker, Vector3(-0.06, 1.2, -0.08), Vector3(0.05, 0.16, 0.1), Color(1.0, 0.82, 0.12))
	Kit.box(_picker, Vector3(0.06, 0.03, 0.08), Vector3(0.12, 0.06, 0.04), Kit.INK)
	spot("picker", "litter picker", Vector3(0.85, 0.6, -4.15), Vector3(0.36, 1.2, 0.36), Vector3(0.9, 0, -3.0),
			"A litter picker: a grabber on a long stick. Standard issue for parks, and for people who have learned not to touch things.",
			_use_picker)

	# The announcement speaker.
	Kit.box(self, Vector3(4.4, 3.05, -4.4), Vector3(0.6, 0.45, 0.2), Color(0.3, 0.31, 0.36))
	Kit.cyl(self, Vector3(4.4, 3.05, -4.27), 0.17, 0.06, Kit.INK, Vector3(90, 0, 0))
	spot("speaker", "loudspeaker", Vector3(4.4, 3.05, -4.35), Vector3(0.7, 0.55, 0.3), Vector3(3.6, 0, -1.0),
			[
				"PA: Welcome to Wyrmhollow, where legends are bred! Please keep arms, legs and expectations inside the walkways.",
				"The announcement is a recording. You are almost sure it didn't say 'expectations' the first time.",
			])

	# A plastic fern, for atmosphere.
	Kit.cyl(self, Vector3(-5.4, 0.25, -3.9), 0.28, 0.5, Color(0.6, 0.35, 0.22), Vector3.ZERO, 0.34)
	for i in 6:
		Kit.box(self, Vector3(-5.4, 0.85, -3.9), Vector3(0.12, 0.9, 0.03), Color(0.25, 0.6, 0.3), Vector3(28, i * 60, 0))
	spot("fern", "fern", Vector3(-5.4, 0.6, -3.9), Vector3(0.7, 1.3, 0.7), Vector3(-4.5, 0, -2.8),
			"A plastic fern. It is wilting anyway.")


# --- Story -------------------------------------------------------------------

func _look_carving() -> void:
	Game.note("Carved on the old arch: a five-clawed print, and beside it a single mark like an upturned V.")
	Game.say([
		"Someone carved a five-clawed print into this arch, a very long time before the gift shop. Beside it is a single mark, like an upturned V.",
		"A plaque reads: ORIGINAL CAVE ART. WE THINK IT MEANS 'WELCOME'.",
		"It does not look like it means welcome. It looks like it is counting.",
	])


func _use_turnstile(item: String) -> void:
	if Game.flag("turnstile_open"):
		main.go_to("hatchery")
	elif item == "token":
		Game.remove_item("token")
		Sfx.play("pickup")
		Game.set_flag("turnstile_open")
		Game.award("paid")
		Game.say("The turnstile swallows the token and unlocks with a cheerful ding. You have paid to enter a disaster.")
	elif item == "":
		Sfx.play("error")
		Game.react("shrug")
		Game.say([
			"The turnstile is locked. A slot says INSERT VISITOR TOKEN.",
			"A smaller sign says NO TOKEN, NO DRAGONS, NO REFUNDS.",
		])
	else:
		refuse(item, "turnstile")


func _use_bell(item: String) -> void:
	if item != "":
		refuse(item, "service bell")
	elif not Game.flag("bell_rung"):
		Sfx.play("bell")
		Game.set_flag("bell_rung")
		Game.award("rang_bell")
		Game.react("startle")
		Game.say([
			"Ding. Nobody comes.",
			"Then, from a long way below the floor: ding.",
			"You decide that was an echo. You decide this firmly.",
		])
	else:
		Sfx.play("pickup")
		Game.add_item("bell")
		Game.set_flag("bell_taken")
		Game.say("You pocket the bell, so that nothing else can ring it at you.")


func _use_cinders(item: String) -> void:
	if Game.flag("token_taken"):
		Game.say("Cinders has nothing left to give. It keeps smiling. That is the worst part.")
	elif item == "picker":
		Sfx.play("pickup")
		Game.add_item("token")
		Game.set_flag("token_taken")
		Game.award("throat")
		Game.say([
			"You feed the litter picker down the statue's throat, feel about, and pull.",
			"Out comes a souvenir token, tangled in a staff lanyard. The lanyard has tooth marks.",
			"The statue does not have teeth. You checked.",
		])
	elif item == "":
		Sfx.play("thunk")
		if not Game.flag("cinders_pulled"):
			Game.set_flag("cinders_pulled")
			Game.react("startle")
			Game.say([
				"You pull the tail. Inside the statue something goes clunk, then stops, then makes the noise of a machine being embarrassed.",
				"Something is jammed in its throat, a long way down.",
				"You are not putting your arm in there. You have read too many incident reports.",
			])
		else:
			Game.say("Still jammed. You would need something long, and a willingness to use it.")
	else:
		refuse(item, "statue")


func _use_staff_door(item: String) -> void:
	if Game.flag("staff_door_open"):
		main.go_to("control")
	elif item == "pass":
		Sfx.play("pickup")
		Game.set_flag("staff_door_open")
		Game.award("trespass")
		Game.say([
			"The reader blinks green. WELCOME BACK, RANGER DEV, says its little screen.",
			"You are not Ranger Dev. You wonder where Ranger Dev is. So does the screen: after a moment it adds a question mark.",
		])
	elif item == "picker":
		Game.say("You could jab the card reader with the litter picker. It would make you feel better. It would not open the door.")
	elif item == "":
		Sfx.play("error")
		Game.react("shrug")
		Game.say("STAFF ONLY. The card reader glows red. It wants a staff pass, and it is not going to be reasonable about it.")
	else:
		refuse(item, "staff door")


func _use_picker(item: String) -> void:
	if item != "":
		refuse(item, "litter picker")
		return
	Sfx.play("pickup")
	Game.add_item("picker")
	Game.set_flag("picker_taken")
	Game.say("You take the litter picker. You feel more official already.")


func _use_leaflets(item: String = "") -> void:
	if item != "":
		refuse(item, "leaflet stand")
	elif Game.flag("leaflet_read"):
		Game.say("You have read it. The cartoon dragons on the cover are waving. One of them is waving at something behind you.")
	else:
		Game.set_flag("leaflet_read")
		Game.note("Leaflet: the MAGPIE WYRM loves anything shiny.")
		Game.note("Leaflet: the EMBER DRAKE follows warmth.")
		Game.note("Leaflet: the ECHO WYVERN repeats what it hears.")
		Game.say([
			"MEET OUR DRAGONS! says the leaflet.",
			"THE MAGPIE WYRM loves anything shiny. Please cover jewellery, phones and fillings.",
			"THE EMBER DRAKE follows warmth. No hot drinks beyond this point.",
			"THE ECHO WYVERN repeats what it hears. Do not tell it your PIN.",
			"You copy the important parts onto your clipboard. All of it seems important.",
		])
