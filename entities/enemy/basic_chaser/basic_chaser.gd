# basic_chaser.gd
# BasicChaser — a straightforward CharacterBody2D enemy that chases and
# touch-damages the player.
#
# This is the renamed, properly-coded successor to what was previously called
# "mascot.gd". The old name was misleading — this node is unambiguously an
# enemy chaser.
#
# EDITOR NOTES:
#   - The scene root must be a CharacterBody2D (this script uses move_and_slide()).
#   - Add a VisionAggroComponent child node and tune detection/lose-sight radii.
#   - Add a StatsComponent child node and set `max_hp` in the Inspector.
#   - Add a CollisionShape2D child for the CharacterBody2D collision layer.
#   - Add the enemy to the "enemies" collision layer and set appropriate masks.

extends CharacterBody2D
class_name BasicChaser

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Movement speed in pixels/second while chasing the player.
@export var move_speed: float = 90.0

## Damage dealt per touch to the player.
@export var touch_damage: float = 10.0

## Minimum seconds between successive touch-damage hits.
@export var touch_damage_cooldown: float = 0.8

## Experience awarded to the player on death.
@export var exp_reward: int = 15

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted just before the chaser is freed; carries the exp reward amount.
signal defeated(exp_reward: int)

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

## Cached player reference (updated each frame from VisionAggroComponent).
var _player: Node2D = null

## Remaining seconds before another touch-damage hit is allowed.
var _damage_cooldown: float = 0.0

# Component references — resolved in _ready via get_node_or_null.
var _vision: VisionAggroComponent = null
var _stats: StatsComponent = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemies")

	# Resolve optional components — warn loudly if missing so designers know.
	_vision = get_node_or_null("VisionAggroComponent")
	_stats = get_node_or_null("StatsComponent")

	if not _vision:
		push_warning("BasicChaser: VisionAggroComponent not found. Add it as a child node.")
	if not _stats:
		push_warning("BasicChaser: StatsComponent not found. Add it as a child node.")

	# Connect signals.
	if _vision:
		_vision.aggro_gained.connect(_on_aggro_gained)
		_vision.aggro_lost.connect(_on_aggro_lost)

	if _stats:
		_stats.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	# Decrement touch-damage cooldown.
	if _damage_cooldown > 0.0:
		_damage_cooldown -= delta

	if _vision and _vision.is_chasing():
		# --- Chase state ---
		var dir: Vector2 = _vision.get_direction_to_target()
		velocity = dir * move_speed

		# Cache player reference for touch-damage checks.
		_player = _vision.get_target()
		_try_touch_damage()
	else:
		# --- Idle state: decelerate to a stop ---
		velocity = Vector2.ZERO

	move_and_slide()

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

## Called by HurtboxComponent, projectiles, or other damage sources.
func take_damage(amount: float = 10.0) -> void:
	if _stats:
		_stats.take_damage(amount)
	else:
		# Fallback: no StatsComponent present — die immediately.
		_on_died()

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

func _on_aggro_gained(_target: Node2D) -> void:
	# Optional: play a "spotted" animation or sound here.
	pass


func _on_aggro_lost() -> void:
	# Optional: return to patrol or play "lost" animation here.
	pass


func _on_died() -> void:
	defeated.emit(exp_reward)
	queue_free()
