extends Hotspot

enum State { SEALED, OPEN, EMPTY }

var state := State.SEALED

@onready var lid: Node3D = $Lid
@onready var key: Node3D = $Key


func interact(item: String) -> void:
	match state:
		State.SEALED:
			if item == "crowbar":
				_pry_open()
			elif item == "":
				Game.say("The lid is nailed down tight. Fingers alone won't shift it.")
			else:
				Game.say("That won't get the lid off.")
		State.OPEN:
			if item == "":
				_take_key()
			else:
				Game.say("It's already open.")
		State.EMPTY:
			Game.say("Nothing left but straw.")


func _pry_open() -> void:
	state = State.OPEN
	display_name = "open crate"
	look_text = "The lid is off. Something brass glints in the straw."
	key.visible = true
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lid, "position", Vector3(0.78, 0.42, 0.0), 0.5)
	tween.tween_property(lid, "rotation_degrees", Vector3(0.0, 0.0, -70.0), 0.5)
	Game.say("The nails shriek and the lid comes away. A brass key lies in the straw.")


func _take_key() -> void:
	state = State.EMPTY
	display_name = "empty crate"
	look_text = "Straw, and the smell of old apples."
	key.visible = false
	Game.add_item("key")
	Game.say("You pocket the brass key.")
