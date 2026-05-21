extends CharacterBody2D

@export var speed: float = 100.0
@export var touch_damage: int = 10
@export var touch_damage_cooldown: float = 0.5
@export var exp_reward: int = 20

signal defeated(exp_reward: int)

var _player: Node2D
var health: int = 3
var _is_touching_player: bool = false
var _damage_cooldown_left: float = 0.0

func _ready():
	_player = get_tree().root.find_child("Player", true, false)
	add_to_group("enemies")
	$Area2D.body_entered.connect(_on_touch_area_body_entered)
	$Area2D.body_exited.connect(_on_touch_area_body_exited)

func _physics_process(delta):
	if not _player:
		return

	var direction = global_position.direction_to(_player.global_position)
	velocity = direction * speed

	move_and_slide()

	if _damage_cooldown_left > 0.0:
		_damage_cooldown_left -= delta

	if _is_touching_player and _damage_cooldown_left <= 0.0 and _player.has_method("take_damage"):
		_player.take_damage(touch_damage)
		_damage_cooldown_left = touch_damage_cooldown

	get_node("Sprite2D").flip_h = velocity.x < 0

func take_damage():
	health -= 1
	if health <= 0:
		defeated.emit(exp_reward)
		queue_free()

func _on_touch_area_body_entered(body: Node2D):
	if body == _player:
		_is_touching_player = true

func _on_touch_area_body_exited(body: Node2D):
	if body == _player:
		_is_touching_player = false
