extends Hotspot


func interact(item: String) -> void:
	if item != "":
		Game.say("That doesn't help.")
		return
	Game.add_item("crowbar")
	Game.say("You take the crowbar. It's heavier than it looks.")
	queue_free()
