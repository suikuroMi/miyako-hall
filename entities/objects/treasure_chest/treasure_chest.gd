# treasure_chest.gd
# Interactive loot chest placed in dungeons, secret groves, and boss chambers.
# Rewards players with rare coins, awakening shards, and spiritual relics.

class_name TreasureChest
extends Node2D

@export var chest_id: String = "chest_forest_01"
@export var reward_coins: int = 120
@export var reward_shards: int = 10
@export var is_opened: bool = false
@export var is_locked: bool = false
@export var required_key_id: String = "shrine_key"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if GameManager and GameManager.get_story_flag(chest_id):
		is_opened = true
		_set_opened_visual()
		return

	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_player: Node2D) -> void:
	if is_opened:
		return

	if is_locked and not GameManager.get_story_flag(required_key_id):
		var hud = get_tree().root.find_child("GameHUD", true, false)
		if hud and hud.has_node("DialogueBox"):
			hud.get_node("DialogueBox").start_dialogue([{
				"speaker": "🔒 Locked Treasure Chest",
				"text": "The chest is sealed by a spiritual lock. Requires [%s] to unlock!" % required_key_id
			}])
		return

	_open_chest()

func _open_chest() -> void:
	is_opened = true
	if GameManager:
		GameManager.set_story_flag(chest_id, true)
		GameManager.shrine_coins += reward_coins
		GameManager.add_character_shards(GameManager.active_character_id, reward_shards)
		if EventBus:
			EventBus.currency_changed.emit(GameManager.shrine_coins)

	if AudioManager:
		AudioManager.play_sfx("coin")
		AudioManager.play_sfx("purified")

	if CameraManager:
		CameraManager.shake(6.0, 0.2)

	_set_opened_visual()

	var hud = get_tree().root.find_child("GameHUD", true, false)
	if hud and hud.has_node("DialogueBox"):
		hud.get_node("DialogueBox").start_dialogue([{
			"speaker": "🎁 Sacred Treasure Chest",
			"text": "Chest Opened! Received +%d Shrine Coins and +%d %s Shards!" % [
				reward_coins,
				reward_shards,
				GameManager.active_character_id.capitalize() if GameManager else "Holomember"
			]
		}])

func _set_opened_visual() -> void:
	if sprite:
		sprite.modulate = Color(0.6, 0.6, 0.65, 0.8)
	if interactable:
		interactable.monitoring = false
		interactable.monitorable = false
