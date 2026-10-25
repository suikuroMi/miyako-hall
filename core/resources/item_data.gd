# item_data.gd
# Base resource for all items, gear, weapons, materials, and consumables.

class_name ItemData
extends Resource

@export_group("Identity")
@export var id: String = "item_id"
@export var name: String = "Item"
@export var description: String = ""
@export var texture: Texture2D

@export_group("Properties")
@export var type: String = "material" # "weapon", "armor", "material", "consumable"
@export var damage: float = 0.0
@export var stackable: bool = false
@export var armor: bool = false
@export var recipe: Array[String] = []

# Alias icon to texture for UI compatibility
var icon: Texture2D:
	get: return texture
	set(val): texture = val
