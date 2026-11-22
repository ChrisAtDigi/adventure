extends Node
## Global game state: inventory, the item currently "in hand", and on-screen messages.
## Registered as the `Game` autoload.

signal inventory_changed
signal selected_item_changed
signal message(text: String)

const ITEM_NAMES := {
	"crowbar": "Crowbar",
	"key": "Brass key",
}

var inventory: Array[String] = []

## Item id the player has picked from the inventory to use on something, or "".
var selected_item := "":
	set(value):
		selected_item = value
		selected_item_changed.emit()


func add_item(id: String) -> void:
	if not inventory.has(id):
		inventory.append(id)
		inventory_changed.emit()


func remove_item(id: String) -> void:
	inventory.erase(id)
	if selected_item == id:
		selected_item = ""
	inventory_changed.emit()


func has_item(id: String) -> bool:
	return inventory.has(id)


func item_name(id: String) -> String:
	return ITEM_NAMES.get(id, id)


func say(text: String) -> void:
	message.emit(text)
