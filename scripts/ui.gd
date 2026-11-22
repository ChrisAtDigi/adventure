class_name GameUI
extends CanvasLayer
## Hover label, message line and inventory bar.

@onready var hover_label: Label = $Hover
@onready var message_label: Label = $Message
@onready var inventory_box: HBoxContainer = $Inventory

var _message_tween: Tween


func _ready() -> void:
	message_label.text = ""
	Game.message.connect(_show_message)
	Game.inventory_changed.connect(_rebuild_inventory)
	Game.selected_item_changed.connect(_rebuild_inventory)
	_rebuild_inventory()


func set_hover(text: String) -> void:
	hover_label.text = text


func _show_message(text: String) -> void:
	if _message_tween:
		_message_tween.kill()
	message_label.text = text
	message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(2.5 + text.length() * 0.05)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


func _rebuild_inventory() -> void:
	for child in inventory_box.get_children():
		child.queue_free()
	for id in Game.inventory:
		var button := Button.new()
		button.text = Game.item_name(id)
		button.toggle_mode = true
		button.button_pressed = id == Game.selected_item
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(130, 44)
		button.pressed.connect(_on_item_pressed.bind(id))
		inventory_box.add_child(button)


func _on_item_pressed(id: String) -> void:
	Game.selected_item = "" if Game.selected_item == id else id
