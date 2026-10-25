# kami_obstacle.gd
# Classic Pokémon-inspired "HM" obstacle (Kami Utility).
# Blocks secret paths or shortcut routes until cleared by a specific Holomember's elemental talent.

class_name KamiObstacle
extends StaticBody2D

enum ObstacleType {
	BURNING_BRAMBLE, # Requires Nakiri Ayame (Flame)
	FROZEN_CHASM,    # Requires Shirakami Fubuki (Frost)
	SPIRIT_WARD      # Requires Ookami Mio (Tarot/Diviner)
}

@export var obstacle_type: ObstacleType = ObstacleType.BURNING_BRAMBLE
@export var obstacle_id: String = "obstacle_bramble_route1"
@export var is_cleared: bool = false

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if GameManager and GameManager.get_story_flag(obstacle_id):
		_clear_silent()
		return

	if interactable:
		interactable.interacted.connect(_on_interacted)

	_setup_visuals()

func _setup_visuals() -> void:
	match obstacle_type:
		ObstacleType.BURNING_BRAMBLE:
			sprite.modulate = Color(0.7, 0.35, 0.25, 1.0)
			if interactable: interactable.prompt_action = "Incinerate Bramble (Requires: Ayame)"
		ObstacleType.FROZEN_CHASM:
			sprite.modulate = Color(0.4, 0.7, 1.3, 1.0)
			if interactable: interactable.prompt_action = "Freeze Frost Bridge (Requires: Fubuki)"
		ObstacleType.SPIRIT_WARD:
			sprite.modulate = Color(0.9, 0.5, 1.2, 1.0)
			if interactable: interactable.prompt_action = "Dispel Spirit Ward (Requires: Mio)"

func _on_interacted(_player: Node2D) -> void:
	if is_cleared or not GameManager:
		return

	var active_id: String = GameManager.active_character_id
	var can_clear: bool = false
	var required_name: String = ""

	match obstacle_type:
		ObstacleType.BURNING_BRAMBLE:
			can_clear = (active_id == "nakiri_ayame")
			required_name = "Nakiri Ayame (Oni Flame)"
		ObstacleType.FROZEN_CHASM:
			can_clear = (active_id == "shirakami_fubuki")
			required_name = "Shirakami Fubuki (Blizzard Kami)"
		ObstacleType.SPIRIT_WARD:
			can_clear = (active_id == "ookami_mio")
			required_name = "Ookami Mio (Tarot Diviner)"

	if can_clear:
		_clear_obstacle()
	else:
		_show_hint(required_name)

func _clear_obstacle() -> void:
	is_cleared = true
	if GameManager:
		GameManager.set_story_flag(obstacle_id, true)

	if AudioManager:
		AudioManager.play_sfx("purified")

	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.6)
	tw.finished.connect(func():
		collision.disabled = true
		if interactable:
			interactable.monitoring = false
			interactable.monitorable = false
		queue_free()
	)

func _clear_silent() -> void:
	is_cleared = true
	queue_free()

func _show_hint(req_name: String) -> void:
	var hud = get_tree().root.find_child("GameHUD", true, false)
	if hud and hud.has_node("DialogueBox"):
		var db = hud.get_node("DialogueBox")
		if db.has_method("start_dialogue"):
			db.start_dialogue([{
				"speaker": "Kami Obstacle",
				"text": "This path is sealed tight. Switch to %s (Hotkey 1/2/3) to channel their elemental power and clear this way!" % req_name
			}])
