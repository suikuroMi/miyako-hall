# jizo_shrine.gd
# Roadside Jizo Statue / Checkpoint Shrine.
# Restores all party members' HP, creates an overworld checkpoint, and saves game progress.

class_name JizoShrine
extends Node2D

@export var checkpoint_id: String = "jizo_route1"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_pray)

func _on_pray(_player: Node2D) -> void:
	# Heal active party members
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("StatsComponent"):
		var stats: StatsComponent = player.get_node("StatsComponent")
		stats.heal(stats.max_hp)

	if GameManager:
		for k in GameManager.party_health.keys():
			var char_data = GameManager.get_character_data(k)
			if char_data:
				GameManager.party_health[k] = char_data.base_health

	if AudioManager:
		AudioManager.play_sfx("purified")

	if SaveManager:
		SaveManager.save_game()

	var hud = get_tree().root.find_child("GameHUD", true, false)
	if hud and hud.has_node("DialogueBox"):
		hud.get_node("DialogueBox").start_dialogue([{
			"speaker": "⛩️ Roadside Jizo Altar",
			"text": "You offered a prayer at the peaceful Jizo shrine. All party members restored to full health, and progress was saved!"
		}])
