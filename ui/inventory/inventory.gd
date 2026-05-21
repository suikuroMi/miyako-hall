extends Control

@onready var mouse_item_node: TextureRect = get_node("MouseItem")
@export var held_item: String

func _ready() -> void:
	self.visible = false
	
	# Initial items
	give("sword")
	give("pickaxe")
	give("chestplate")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		toggle_inventory()

func toggle_inventory():
	self.visible = !self.visible
	
	get_tree().paused = self.visible
	
	if self.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	if self.visible:
		mouse_item_node.global_position = get_global_mouse_position() - Vector2(32, 32)

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