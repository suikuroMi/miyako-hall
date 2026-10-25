# hidden_item.gd
# Interactive secret sparkle spot hidden behind world geometry (trees, rocks, lanterns).
# Rewards observant players with extra coins, crafting herbs, and rare tokens upon inspection.

class_name HiddenItem
extends Node2D

@export var item_id: String = "hidden_cache_01"
@export var coin_reward: int = 75
@export var prompt_text: String = "Inspect Sparkle"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var sprite: Sprite2D = $Sprite2D

var _sparkle_time: float = 0.0

func _ready() -> void:
	if GameManager and GameManager.get_story_flag(item_id):
		queue_free()
		return

	if interactable:
		interactable.interacted.connect(_on_found)

func _process(delta: float) -> void:
	_sparkle_time += delta * 4.0
	if sprite:
		sprite.modulate.a = 0.35 + sin(_sparkle_time) * 0.35
		sprite.scale = Vector2.ONE * (0.4 + sin(_sparkle_time * 0.5) * 0.08)

func _on_found(_player: Node2D) -> void:
	if GameManager:
		GameManager.set_story_flag(item_id, true)
		GameManager.shrine_coins += coin_reward
		if EventBus:
			EventBus.currency_changed.emit(GameManager.shrine_coins)

	if AudioManager:
		AudioManager.play_sfx("coin")

	var hud = get_tree().root.find_child("GameHUD", true, false)
	if hud and hud.has_node("DialogueBox"):
		var db = hud.get_node("DialogueBox")
		if db.has_method("start_dialogue"):
			db.start_dialogue([{
				"speaker": "✨ Hidden Discovery",
				"text": "You uncovered a secret spiritual cache! Received +%d Shrine Coins!" % coin_reward
			}])

	queue_free()
