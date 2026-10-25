# base_enemy.gd
# Base class for all hostile entities in Miyako Hall.
# Unifies StatsComponent, MovementComponent, HurtboxComponent, HitboxComponent,
# VisionAggroComponent, and NavigationAgent2D into a clean, reusable template.

class_name BaseEnemy
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export_group("Stats & Rewards")
@export var enemy_name: String = "Enemy"
@export var exp_reward: int = 20
@export var touch_damage: float = 10.0
@export var touch_cooldown: float = 0.8

@export_group("Movement & Navigation")
@export var move_speed: float = 80.0
@export var use_navigation: bool = false

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal defeated(exp_amount: int)

# ---------------------------------------------------------------------------
# Pre-attached Child Components
# ---------------------------------------------------------------------------
@onready var stats: StatsComponent = get_node_or_null("StatsComponent")
@onready var movement: MovementComponent = get_node_or_null("MovementComponent")
@onready var vision: VisionAggroComponent = get_node_or_null("VisionAggroComponent")
@onready var hurtbox: HurtboxComponent = get_node_or_null("HurtboxComponent")
@onready var hitbox: HitboxComponent = get_node_or_null("HitboxComponent")
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var sprite: Node2D = get_node_or_null("Sprite2D")

var _damage_timer: float = 0.0
var _is_dying: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemies")

	if stats:
		stats.died.connect(_on_died)
	if vision:
		vision.aggro_gained.connect(_on_aggro_gained)
		vision.aggro_lost.connect(_on_aggro_lost)

	_setup_enemy()

func _setup_enemy() -> void:
	# Virtual hook for child scenes to override
	pass

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	if _damage_timer > 0.0:
		_damage_timer -= delta

	if vision and vision.is_chasing():
		var target: Node2D = vision.get_target()
		var move_dir: Vector2 = Vector2.ZERO

		if use_navigation and nav_agent and is_instance_valid(target):
			nav_agent.target_position = target.global_position
			if not nav_agent.is_navigation_finished():
				var next_path_pos: Vector2 = nav_agent.get_next_path_position()
				move_dir = (next_path_pos - global_position).normalized()
		else:
			move_dir = vision.get_direction_to_target()

		if movement:
			movement.base_speed = move_speed
			velocity = movement.get_full_velocity(move_dir)
		else:
			velocity = move_dir * move_speed

		_try_touch_damage(target)
		_update_chase_visuals(move_dir)
	else:
		if movement:
			velocity = movement.get_full_velocity(Vector2.ZERO)
		else:
			velocity = Vector2.ZERO
		_update_idle_visuals()

	move_and_slide()

# ---------------------------------------------------------------------------
# Combat & Interactions
# ---------------------------------------------------------------------------

func _try_touch_damage(target: Node2D) -> void:
	if not is_instance_valid(target) or _damage_timer > 0.0:
		return
	var dist = global_position.distance_to(target.global_position)
	if dist <= 36.0:
		if target.has_method("take_damage"):
			target.take_damage(touch_damage)
			_damage_timer = touch_cooldown

func take_damage(amount: float) -> void:
	if stats:
		stats.take_damage(amount)
	else:
		_on_died()

func _update_chase_visuals(move_dir: Vector2) -> void:
	if sprite and move_dir.x != 0.0:
		sprite.scale.x = abs(sprite.scale.x) * sign(move_dir.x)
	if anim_player and anim_player.has_animation("walk"):
		anim_player.play("walk")

func _update_idle_visuals() -> void:
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

func _on_aggro_gained(_target: Node2D) -> void:
	pass

func _on_aggro_lost() -> void:
	pass

func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	defeated.emit(exp_reward)
	if EventBus:
		EventBus.enemy_purified.emit(null, global_position, exp_reward)

	if anim_player and anim_player.has_animation("hurt"):
		anim_player.play("hurt")
		await anim_player.animation_finished

	queue_free()
