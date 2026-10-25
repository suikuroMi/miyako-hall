# shrine_upgrade_station.gd
# Interactive shrine expansion pavilion in Kamikitakuni Shrine hub.
# Allows players to rebuild structures and unlock passive account-wide buffs.

class_name ShrineUpgradeStation
extends Node2D

@onready var interactable: InteractableComponent = $InteractableComponent

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_player: Node2D) -> void:
	if not GameManager:
		return

	match GameManager.shrine_tier:
		1:
			if GameManager.shrine_coins >= 150:
				GameManager.upgrade_shrine_tier()
				_show_dialogue("⛩️ Shrine Rebuilt: Tier 2 (Torii Wards)!", "Sacred spiritual wards erected! All party members gain +15% Movement Speed across all zones.")
			else:
				_show_dialogue("⛩️ Shrine Renovation", "Rebuilding the Sacred Torii Wards requires 150 Shrine Coins. (Current: %d Coins). Rescue wandering souls and purify enemies to gather faith!" % GameManager.shrine_coins)
		2:
			if GameManager.shrine_coins >= 300:
				GameManager.upgrade_shrine_tier()
				_show_dialogue("🌸 Shrine Rebuilt: Tier 3 (Spirit Garden)!", "Herbal Spirit Garden bloomed! Unlocked +10% Gacha Banner Luck and +20% EXP Bonus.")
			else:
				_show_dialogue("⛩️ Shrine Renovation", "Cultivating the Herbal Spirit Garden requires 300 Shrine Coins. (Current: %d Coins)." % GameManager.shrine_coins)
		3:
			_show_dialogue("✨ Kamikitakuni Grand Sanctuary", "The Shrine is fully restored and radiating spiritual grace! All party buffs and divine protections are active.")

func _show_dialogue(speaker: String, text: String) -> void:
	var hud = get_tree().root.find_child("GameHUD", true, false)
	if hud and hud.has_node("DialogueBox"):
		var db = hud.get_node("DialogueBox")
		if db.has_method("start_dialogue"):
			db.start_dialogue([{
				"speaker": speaker,
				"text": text
			}])
