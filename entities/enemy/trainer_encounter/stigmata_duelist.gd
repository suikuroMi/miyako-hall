# stigmata_duelist.gd
# Classic Pokémon Trainer-style Line-of-Sight Overworld Encounter.
# Catches the player's eye when they cross its sightline, triggering an arena duel!

class_name StigmataDuelist
extends CharacterBody2D

signal duel_completed()

@export var encounter_id: String = "duelist_route1_01"
@export var sight_distance: float = 240.0
@export var facing_direction: Vector2 = Vector2.DOWN
@export var reward_coins: int = 150

var _is_defeated: bool = false
var _has_triggered: bool = false
var _player: Node2D = null

@onready var sight_ray: RayCast2D = $SightRay
@onready var sprite: Sprite2D = $Sprite2D
@onready var stats: StatsComponent = $StatsComponent

func _ready() -> void:
	if GameManager and GameManager.get_story_flag(encounter_id):
		_is_defeated = true
		queue_free()
		return

	add_to_group("enemies")

	if sight_ray:
		sight_ray.target_position = facing_direction.normalized() * sight_distance
		sight_ray.collision_mask = 1 # Player layer

	if stats:
		stats.died.connect(_on_defeated)

	_player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if _has_triggered or _is_defeated:
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return

	# Check sightline cone to player
	var to_player: Vector2 = _player.global_position - global_position
	var dist: float = to_player.length()

	if dist <= sight_distance:
		var dot: float = facing_direction.normalized().dot(to_player.normalized())
		if dot > 0.70: # ~45 degree forward sight cone
			_trigger_trainer_encounter()

func _trigger_trainer_encounter() -> void:
	_has_triggered = true

	# Display "!" exclamation mark
	var bubble := Label.new()
	bubble.text = "!"
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	bubble.position = Vector2(-8, -48)
	add_child(bubble)

	if AudioManager:
		AudioManager.play_sfx("hit")

	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2(1.3, 1.3), 0.15)
	tw.parallel().tween_property(bubble, "position:y", -60.0, 0.3)
	tw.finished.connect(bubble.queue_free)

	# Trigger dialogue
	var lines := [
		{
			"speaker": "⚔️ Corrupted Stigmata Duellist",
			"text": "HALT! You crossed my vision! The False Moon commands your spirit to submit to the nexus!"
		},
		{
			"speaker": "Ookami Mio",
			"text": "Another soul possessed by the stigmata... Prepare yourself, I will purify your heart!"
		}
	]

	if EventBus:
		EventBus.dialogue_started.emit(lines)

func _on_defeated() -> void:
	_is_defeated = true
	if GameManager:
		GameManager.set_story_flag(encounter_id, true)
		GameManager.shrine_coins += reward_coins
		if EventBus:
			EventBus.currency_changed.emit(GameManager.shrine_coins)

	if AudioManager:
		AudioManager.play_sfx("purified")

	duel_completed.emit()
	queue_free()
