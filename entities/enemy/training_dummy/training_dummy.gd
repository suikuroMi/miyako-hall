extends CharacterBody2D
class_name TrainingDummy

enum Behavior { STANDING, CHASING, CHASING_AND_ATTACKING }

@export var max_health: int = 100
@export var behavior: Behavior = Behavior.STANDING
@export var move_speed: float = 70.0
@export var attack_damage: int = 10
@export var attack_range: float = 48.0
@export var attack_cooldown: float = 1.0

var health: int
var _attack_timer: float = 0.0
var _player: CharacterBody2D

@onready var _health_label: Label = $HealthLabel
@onready var _mode_label: Label = $ModeLabel

func _ready() -> void:
	add_to_group("training_dummies")
	health = max_health
	_player = get_tree().root.find_child("Player", true, false) as CharacterBody2D
	_refresh_labels()
	_set_color()

func configure(new_behavior: Behavior) -> void:
	behavior = new_behavior

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta

	if behavior == Behavior.STANDING or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		return

	var offset := _player.global_position - global_position
	var distance := offset.length()
	if distance > attack_range:
		velocity = offset.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if behavior == Behavior.CHASING_AND_ATTACKING and distance <= attack_range and _attack_timer <= 0.0:
		if _player.has_method("take_damage"):
			_player.take_damage(attack_damage)
		_attack_timer = attack_cooldown

func take_damage(amount: int = 25) -> void:
	if amount <= 0:
		return
	health = maxi(health - amount, 0)
	_refresh_labels()
	if health == 0:
		queue_free()

func _refresh_labels() -> void:
	if not is_node_ready():
		return
	_health_label.text = "HP %d / %d" % [health, max_health]
	match behavior:
		Behavior.STANDING:
			_mode_label.text = "STANDING DUMMY"
		Behavior.CHASING:
			_mode_label.text = "CHASE DUMMY"
		Behavior.CHASING_AND_ATTACKING:
			_mode_label.text = "ATTACK DUMMY"

func _set_color() -> void:
	var color := Color(0.3, 0.75, 0.95)
	if behavior == Behavior.CHASING:
		color = Color(1.0, 0.72, 0.25)
	elif behavior == Behavior.CHASING_AND_ATTACKING:
		color = Color(1.0, 0.35, 0.35)
	$Body.color = color
