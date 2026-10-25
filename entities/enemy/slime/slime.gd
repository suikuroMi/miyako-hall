# slime.gd
# Slime enemy — a simple Node2D-based enemy that chases and touch-damages the player.
#
# EDITOR NOTES (IMPORTANT):
#   - The root node of slime.tscn is a Node2D named "Slime" — NOT a CharacterBody2D.
#     Movement is therefore done via `global_position += velocity * delta`.
#   - Add a VisionAggroComponent child node in slime.tscn and tune its radii.
#   - Add a StatsComponent child node in slime.tscn and set `max_hp` in the Inspector.
#   - The AnimationPlayer node must have its "unique_name_in_owner" flag enabled in the
#     Inspector so that %AnimationPlayer resolves correctly.
#   - Animations required in AnimationPlayer (default library, no prefix):
#       "idle", "walk", "hurt"

extends Node2D
class_name Slime

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Movement speed in pixels/second while chasing the player.
@export var move_speed: float = 60.0

## Damage dealt per touch to the player.
@export var touch_damage: float = 8.0

## Minimum seconds between successive touch-damage hits.
@export var touch_damage_cooldown: float = 0.8

## Experience awarded to the player on death.
@export var exp_reward: int = 20

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted just before the slime is freed; carries the exp reward amount.
signal defeated(exp_reward: int)

# ---------------------------------------------------------------------------
# Onready references
# ---------------------------------------------------------------------------

## AnimationPlayer must have unique_name_in_owner = true in the scene.
@onready var _anim: AnimationPlayer = %AnimationPlayer

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

var _player: Node2D = null
var _damage_cooldown: float = 0.0
var _velocity: Vector2 = Vector2.ZERO

# Component references resolved at runtime (may be null if not added in editor).
var _vision: VisionAggroComponent = null
var _stats: StatsComponent = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemies")

	# Resolve optional child components.
	_vision = get_node_or_null("VisionAggroComponent")
	_stats = get_node_or_null("StatsComponent")

	# Connect VisionAggroComponent signals.
	if _vision:
		_vision.aggro_gained.connect(_on_aggro_gained)
		_vision.aggro_lost.connect(_on_aggro_lost)

	# Connect StatsComponent death signal.
	if _stats:
		_stats.died.connect(_on_died)

	_anim.play("idle")


func _physics_process(delta: float) -> void:
	# Decrement the touch-damage cooldown timer.
	if _damage_cooldown > 0.0:
		_damage_cooldown -= delta

	if _vision and (_vision.is_chasing() or _vision.is_investigating()):
		# --- Chase / Investigate state ---
		var spd: float = move_speed if _vision.is_chasing() else move_speed * 0.6
		var dir: Vector2 = _vision.get_direction_to_target()
		_velocity = dir * spd
		global_position += _velocity * delta

		if _vision.is_chasing():
			# Keep a local reference to the player for touch damage checks.
			_player = _vision.get_target()
			_try_touch_damage()

		# Only switch to walk anim if the slime isn't currently playing "hurt".
		if _anim.current_animation != "hurt":
			_anim.play("walk")
	else:
		# --- Idle state ---
		_velocity = Vector2.ZERO
		if _anim.current_animation != "hurt":
			_anim.play("idle")

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Deals touch damage to the player if within range and cooldown has expired.
func _try_touch_damage() -> void:
	if not _player or not is_instance_valid(_player):
		return
	if _damage_cooldown > 0.0:
		return

	var dist: float = global_position.distance_to(_player.global_position)
	if dist > 32.0:
		return  # Not close enough for a touch hit.

	if _player.has_method("take_damage"):
		_player.take_damage(touch_damage)
		_damage_cooldown = touch_damage_cooldown

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by HurtboxComponent or projectiles to deal damage to this slime.
func take_damage(amount: float = 10.0) -> void:
	if _stats:
		_stats.take_damage(amount)
	else:
		# Fallback: no StatsComponent present — die immediately.
		_on_died()
		return

	# Play hurt animation, then return to the appropriate looping animation.
	_anim.play("hurt")
	await _anim.animation_finished

	# Guard: the slime may have been freed during the animation.
	if not is_instance_valid(self):
		return

	if _vision and _vision.is_chasing():
		_anim.play("walk")
	else:
		_anim.play("idle")

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

func _on_aggro_gained(_target: Node2D) -> void:
	_anim.play("walk")


func _on_aggro_lost() -> void:
	_anim.play("idle")


func _on_died() -> void:
	defeated.emit(exp_reward)
	queue_free()
