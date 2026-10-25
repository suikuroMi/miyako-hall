# lost_soul.gd
# Interactive Wandering Soul / Panicked Old Stigmata NPC.
# When players interact and purify the soul, it grants Faith & EXP,
# updates the rescued spirits tracker, and ascends to the Shrine hub.

class_name LostSoul
extends Node2D

@export var soul_id: String = "soul_route1_01"
@export var soul_name: String = "Wandering Shrine Villager"
@export var coin_reward: int = 50
@export var exp_reward: int = 60

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var sprite: Sprite2D = $Sprite2D

var _time_passed: float = 0.0

func _ready() -> void:
	if GameManager and GameManager.is_spirit_rescued(soul_id):
		queue_free()
		return

	_time_passed = randf_range(0.0, TAU)
	if interactable:
		interactable.interaction_completed.connect(_on_purified)

func _process(delta: float) -> void:
	_time_passed += delta * 2.8
	if sprite:
		sprite.position.y = sin(_time_passed) * 5.0
		sprite.modulate = Color(0.7, 0.95, 1.2, 0.75 + sin(_time_passed * 2.0) * 0.25)

func _on_purified() -> void:
	if GameManager:
		GameManager.rescue_spirit(soul_id)
		GameManager.add_shrine_coins(coin_reward)

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_experience"):
		player.add_experience(exp_reward)

	if AudioManager:
		AudioManager.play_sfx("purified")

	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 90.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.85)
	tw.finished.connect(queue_free)
