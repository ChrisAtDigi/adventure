extends Hotspot

var open := false

@onready var pivot: Node3D = $Pivot


func interact(item: String) -> void:
	if open:
		Game.say("The way is open. That's the end of the prototype: one room, one puzzle, solved.")
	elif item == "key":
		_unlock()
	elif item == "crowbar":
		Game.say("Solid oak. The crowbar only chews splinters off the frame.")
	elif item == "":
		Game.say("Locked. The keyhole is rimmed with brass.")
	else:
		Game.say("That doesn't fit the lock.")


func _unlock() -> void:
	open = true
	display_name = "open doorway"
	look_text = "Darkness beyond, and a draught that smells of the sea."
	Game.remove_item("key")
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(pivot, "rotation_degrees:y", -100.0, 0.9)
	Game.say("The key turns with a clunk and the door swings open.")
