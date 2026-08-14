extends Control

@export var held_item: String

func _ready() -> void:
	self.visible = false
	
	# Initial items
	give("sycte")
	give("pickaxe")
	give("chestplate")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		toggle_inventory()

func toggle_inventory():
	self.visible = !self.visible
	get_tree().paused = self.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func give(id: String):
	var slots_parent = get_node("%Slots")
	
	if List.item[id].stackable:
		for i in slots_parent.get_child_count():
			var slot = slots_parent.get_child(i)
			if not slot.armor and slot.data == List.item[id]:
				slot.count += 1
				slot.update()
				return
	
	for i in slots_parent.get_child_count():
		var slot = slots_parent.get_child(i)
		if not slot.armor and slot.data == null:
			slot.data = List.item[id]
			slot.count = 1
			slot.update()
			return

func _on_button_pressed() -> void:
	give("coin")
