class_name Hotspot
extends StaticBody3D
## Something in a room the player can look at or use. Created with Room.spot().

var id := ""
var display_name := "thing"
## Where the inspector stands to use it.
var approach := Vector3.ZERO
## Called with no arguments on a right click.
var look_handler := Callable()
## Called with the inventory item being used on it, or "" for a plain interaction.
var use_handler := Callable()


func set_active(active: bool) -> void:
	collision_layer = 1 if active else 0
