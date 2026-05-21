extends CharacterBody2D

@export var base_speed: float = 150.0
@export var max_health: int = 100
@export var base_exp_to_next_level: int = 100
@export var exp_growth_factor: float = 1.25

signal health_changed(current_health: int, max_health: int)
signal exp_changed(current_exp: int, exp_to_next_level: int, level: int)
signal level_changed(level: int)
signal level_up_choices_changed(pending_choices: int)
signal stats_changed(damage: int, speed: int, intelligence: int, max_health: int)

var health: int = 100
var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 100
var pending_level_up_choices: int = 0

var stat_damage: int = 10
var stat_speed: int = 10
var stat_intelligence: int = 10

var _sprite: AnimatedSprite2D
var _facing: String = "right"

func _ready():
	_sprite = get_node("mio/AnimatedSprite2D")
	health = max_health
	exp_to_next_level = base_exp_to_next_level

	health_changed.emit(health, max_health)
	exp_changed.emit(current_exp, exp_to_next_level, level)
	level_up_choices_changed.emit(pending_level_up_choices)
	stats_changed.emit(stat_damage, stat_speed, stat_intelligence, max_health)

func _physics_process(_delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * get_movement_speed()

		if direction.x > 0:
			_facing = "right"
		elif direction.x < 0:
			_facing = "left"

		_sprite.play("walk_" + _facing)
	else:
		_sprite.play("idle_" + _facing)
		velocity = direction * get_movement_speed()

	move_and_slide()

func take_damage(amount: int = 10):
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)

func heal(amount: int):
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

func add_experience(amount: int):
	if amount <= 0:
		return

	current_exp += amount
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level += 1
		pending_level_up_choices += 1
		level_changed.emit(level)
		exp_to_next_level = maxi(int(round(exp_to_next_level * exp_growth_factor)), 1)

	exp_changed.emit(current_exp, exp_to_next_level, level)
	level_up_choices_changed.emit(pending_level_up_choices)

func get_movement_speed() -> float:
	return base_speed + ((stat_speed - 10) * 5.0)

func get_attack_damage() -> int:
	return stat_damage

func get_intelligence() -> int:
	return stat_intelligence

func apply_level_up_choice(choice_id: String):
	if pending_level_up_choices <= 0:
		return

	match choice_id:
		"ATK":
			stat_damage += 3
		"SPD":
			stat_speed += 2
		"INT":
			stat_intelligence += 2
		"VIT":
			max_health += 20
			health = mini(health + 20, max_health)
		_:
			return

	pending_level_up_choices -= 1
	health_changed.emit(health, max_health)
	stats_changed.emit(stat_damage, stat_speed, stat_intelligence, max_health)
	level_up_choices_changed.emit(pending_level_up_choices)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_H:
				take_damage(10)
			KEY_J:
				heal(10)
			KEY_K:
				add_experience(25)
