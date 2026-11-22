extends Node
## Global game state: story flags, inventory, clipboard notes, achievements and saving.
## Registered as the `Game` autoload.

signal inventory_changed
signal selected_item_changed
signal narration(lines: Array)
signal note_added(text: String)
signal achievement_unlocked(id: String)
signal flag_changed(flag_name: String)

const SAVE_PATH := "user://adventure_save.json"
## The cave's idea of a perfect score. Chapter One cannot reach it. That's the joke.
const MAX_SCORE := 350

const ITEMS := {
	"picker": {
		"name": "Litter picker",
		"desc": "A grabber on a stick, for people who would rather not touch things.",
	},
	"token": {
		"name": "Souvenir token",
		"desc": "Stamped with a smiling dragon. Slightly chewed.",
	},
	"bell": {
		"name": "Service bell",
		"desc": "Brass, and polished to a shine. Ring for service. Results may vary.",
	},
	"pass": {
		"name": "Staff pass",
		"desc": "RANGER DEV, HATCHERY. The photo is smiling. The lanyard has tooth marks.",
	},
}

const ACHIEVEMENTS := {
	"read_sign": {"title": "Read A Sign", "sub": "Most people don't.", "points": 5},
	"rang_bell": {"title": "Rang For Service", "sub": "Service is considering it.", "points": 5},
	"throat": {"title": "Reached Into A Throat", "sub": "It wasn't in the job description.", "points": 10},
	"paid": {"title": "Paid To Enter A Disaster", "sub": "No refunds.", "points": 10},
	"tapped": {"title": "Tapped The Glass", "sub": "The glass has a policy on that.", "points": 5},
	"trade": {"title": "Bribed A Dragon", "sub": "It will remember this. Fondly.", "points": 15},
	"trespass": {"title": "Authorised Personnel, Technically", "sub": "Welcome back, Ranger Dev.", "points": 10},
	"jingle": {"title": "Tried To Stop The Jingle", "sub": "Others have tried.", "points": 5},
	"overload": {"title": "Tripped It", "sub": "Not 6. They tried 6.", "points": 5},
	"fences": {"title": "Did The Thing Every Film Warns About", "sub": "The gates say thank you.", "points": 15},
	"counted": {"title": "Counted Like A Cave", "sub": "It noticed.", "points": 20},
}

var flags := {}
var inventory: Array[String] = []
var notes: Array[String] = []
var achievements: Array[String] = []
var room_id := ""

## Set by the smoke test: no saving, no waiting on text or fades.
var test_mode := false

## Item id picked from the inventory to use on something, or "".
var selected_item := "":
	set(value):
		selected_item = value
		selected_item_changed.emit()


func reset() -> void:
	flags.clear()
	inventory.clear()
	notes.clear()
	achievements.clear()
	room_id = ""
	selected_item = ""
	inventory_changed.emit()


func flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func set_flag(flag_name: String, value := true) -> void:
	if flag(flag_name) == value:
		return
	flags[flag_name] = value
	flag_changed.emit(flag_name)
	save_game()


func add_item(id: String) -> void:
	if not inventory.has(id):
		inventory.append(id)
		inventory_changed.emit()
		save_game()


func remove_item(id: String) -> void:
	inventory.erase(id)
	if selected_item == id:
		selected_item = ""
	inventory_changed.emit()
	save_game()


func has_item(id: String) -> bool:
	return inventory.has(id)


func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


## Show narration. Accepts one line or an array of lines.
## A line starting with "PA: " is spoken by the park's announcement system.
func say(lines: Variant) -> void:
	var list: Array = lines if lines is Array else [lines]
	narration.emit(list)


## Record an observation on the inspector's clipboard (once).
func note(text: String) -> void:
	if not notes.has(text):
		notes.append(text)
		note_added.emit(text)
		save_game()


func award(id: String) -> void:
	if ACHIEVEMENTS.has(id) and not achievements.has(id):
		achievements.append(id)
		achievement_unlocked.emit(id)
		save_game()


func score() -> int:
	var total := 0
	for id in achievements:
		total += int(ACHIEVEMENTS[id]["points"])
	return total


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if test_mode or room_id == "":
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"room": room_id,
		"flags": flags,
		"inventory": inventory,
		"notes": notes,
		"achievements": achievements,
	}))


func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return false
	reset()
	flags = data.get("flags", {})
	inventory.assign(data.get("inventory", []))
	notes.assign(data.get("notes", []))
	achievements.assign(data.get("achievements", []))
	room_id = data.get("room", "lobby")
	inventory_changed.emit()
	return true
