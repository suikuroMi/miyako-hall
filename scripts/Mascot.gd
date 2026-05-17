extends CharacterBody2D

@export var speed: float = 100.0
var _player: Node2D
var health: int = 3

func _ready():
	_player = get_tree().root.find_child("Player", true, false)
	add_to_group("enemies") 

func _physics_process(_delta):
	if not _player:
		return

	var direction = global_position.direction_to(_player.global_position)
	velocity = direction * speed

	move_and_slide()
	
	get_node("Sprite2D").flip_h = velocity.x < 0

func take_damage():
	health -= 1
	if health == 0:
		queue_free()
