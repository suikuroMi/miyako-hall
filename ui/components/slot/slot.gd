extends Button

@export var data: Item
@export var count: int
@export var armor: bool
@export var crafting_output: bool
@export var crafting_slot: bool
@export var craft_index: int

@onready var icon_rect: TextureRect = get_node("TextureRect")
@onready var count_label: Label = get_node("TextureRect/Count")

func _ready() -> void:
	update()
	get_node("Armor").visible = armor

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not data or crafting_output:
		return null
		
	var preview = TextureRect.new()
	preview.texture = data.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(48, 48)
	set_drag_preview(preview)
	
	return self

func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if not drag_data is Button or drag_data == self:
		return false
		
	if name == "WeaponSlot":
		if not drag_data.data:
			return false
		return drag_data.data.type == "weapon"
		
	return true

func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	var source_slot = drag_data
	
	if name == "WeaponSlot":
		var temp_data = data
		var temp_count = count
		
		data = source_slot.data
		count = source_slot.count
		
		source_slot.data = temp_data
		source_slot.count = temp_count
	else:
		if data and data == source_slot.data and data.stackable:
			count += source_slot.count
			source_slot.data = null
			source_slot.count = 0
		else:
			var temp_data = data
			var temp_count = count
			
			data = source_slot.data
			count = source_slot.count
			
			source_slot.data = temp_data
			source_slot.count = temp_count
		
	update()
	source_slot.update()

func update():
	if data:
		icon_rect.texture = data.texture 
		count_label.text = str(count)
		tooltip_text = data.name
		if crafting_slot:
			get_parent().get_parent().update_recipe(craft_index, data.id)
		if data.stackable:
			count_label.visible = count > 1
			if count <= 0:
				data = null
				update()
		else:
			count_label.visible = false
			
		if name == "WeaponSlot":
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				players[0].equip_weapon(data)
	else:
		icon_rect.texture = null
		count_label.text = ""
		tooltip_text = ""
		if crafting_slot:
			get_parent().get_parent().update_recipe(craft_index, "")
			
		if name == "WeaponSlot":
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				players[0].unequip_weapon()