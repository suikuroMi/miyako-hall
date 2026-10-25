# cooking_crafting_station.gd
# Interactive outdoor cooking hearth & talisman altar in Kamikitakuni Shrine hub.
# Interacting opens the CookingStationMenu UI.

class_name CookingCraftingStation
extends Node2D

@onready var interactable: InteractableComponent = $InteractableComponent

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_player: Node2D) -> void:
	var hud = get_tree().root.find_child("GameHUD", true, false)
	if hud and hud.has_node("CookingStationMenu"):
		var menu = hud.get_node("CookingStationMenu")
		if menu.has_method("open_menu"):
			menu.open_menu()
		else:
			menu.visible = true
