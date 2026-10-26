# pushable_boulder.gd
# Pushable stone boulder for overworld & temple environmental puzzles.
# Pushed by player body movement when contacted.

class_name PushableBoulder
extends CharacterBody2D

@export var push_friction: float = 400.0
@export var boulder_mass: float = 1.0

var _is_being_pushed: bool = false
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 4 # World obstacle layer
	collision_mask = 1 | 4 # Player and other obstacles

func _physics_process(delta: float) -> void:
	# Decelerate boulder gradually
	velocity = velocity.move_toward(Vector2.ZERO, push_friction * delta)
	move_and_slide()

## Called when player moves into the boulder
func push(push_direction: Vector2, strength: float = 120.0) -> void:
	velocity = push_direction.normalized() * (strength / boulder_mass)
	if CameraManager:
		CameraManager.shake(2.0, 0.1)
