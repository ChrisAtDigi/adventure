class_name Hotspot
extends StaticBody3D
## Something in a room the player can look at or interact with.
## Add a Marker3D child named "Approach" to set where the character stands to use it.

@export var display_name := "thing"
@export_multiline var look_text := "Nothing special."


func approach_position() -> Vector3:
	var marker := get_node_or_null("Approach") as Node3D
	return marker.global_position if marker else global_position


func look() -> void:
	Game.say(look_text)


## Called once the character has walked over. `item` is the inventory item being
## used on this hotspot, or "" for a plain interaction.
func interact(_item: String) -> void:
	Game.say("Nothing happens.")
