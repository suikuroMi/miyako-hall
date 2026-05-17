extends CharacterBody2D

@export var speed: float = 150.0
var _sprite: AnimatedSprite2D
var _facing: String = "right"

func _ready():
	_sprite = get_node("mio/AnimatedSprite2D")

func _physics_process(_delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed

		if direction.x > 0:
			_facing = "right"
		elif direction.x < 0:
			_facing = "left"

		_sprite.play("walk_" + _facing)
	else:
		_sprite.play("idle_" + _facing)
		velocity = direction * speed

	move_and_slide()
