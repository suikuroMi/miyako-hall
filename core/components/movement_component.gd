# movement_component.gd
# MovementComponent — handles velocity calculation, dash, and knockback decay.
# Attach as a child Node to any entity (player or enemy).
# The parent entity should call get_full_velocity() each physics frame,
# assign the result to its own `velocity`, then call move_and_slide().
#
# EDITOR NOTES:
#   - Add as a child Node in the scene tree of any entity that needs movement.
#   - Tune base_speed, dash_speed_multiplier, dash_duration, dash_cooldown, and
#     knockback_decay in the Inspector per entity.

class_name MovementComponent extends Node

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Base movement speed in pixels/second.
@export var base_speed: float = 100.0

## Multiplier applied to base_speed during a dash.
@export var dash_speed_multiplier: float = 3.0

## How long (in seconds) the dash lasts.
@export var dash_duration: float = 0.18

## Cooldown (in seconds) before the entity can dash again.
@export var dash_cooldown: float = 0.7

## Deceleration rate (pixels/s²) applied to knockback velocity each frame.
@export var knockback_decay: float = 800.0

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted the moment a dash begins.
signal dash_started

## Emitted the moment a dash finishes naturally (not cancelled).
signal dash_ended

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

var _knockback_velocity: Vector2 = Vector2.ZERO
var _dash_velocity: Vector2 = Vector2.ZERO
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _is_dashing: bool = false

# ---------------------------------------------------------------------------
# Physics process
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Count down dash duration and cooldown timers.
	if _dash_timer > 0.0:
		_dash_timer -= delta

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta

	# End the dash when the dash timer expires.
	if _is_dashing and _dash_timer <= 0.0:
		_is_dashing = false
		_dash_velocity = Vector2.ZERO
		dash_ended.emit()

	# Decay knockback velocity toward zero each frame.
	# move_toward on the vector length preserves direction while shrinking magnitude.
	var kb_length: float = _knockback_velocity.length()
	if kb_length > 0.0:
		var new_length: float = move_toward(kb_length, 0.0, knockback_decay * delta)
		_knockback_velocity = _knockback_velocity.normalized() * new_length

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the base walking/running velocity for the given direction.
## Does NOT include dash or knockback — use get_full_velocity() for that.
## `equipped_weapon` is reserved for future speed-modifier weapons and is
## currently unused.
func get_move_velocity(direction: Vector2, _equipped_weapon: Resource = null) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	return direction.normalized() * base_speed


## Returns the complete velocity the parent should apply this frame:
## base movement + active dash + active knockback.
func get_full_velocity(direction: Vector2) -> Vector2:
	return get_move_velocity(direction) + _dash_velocity + _knockback_velocity


## Attempts to start a dash in `direction`.
## Silently returns if the entity is already dashing or still in cooldown.
func try_dash(direction: Vector2) -> void:
	if _dash_cooldown_timer > 0.0 or _is_dashing:
		return

	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_velocity = direction.normalized() * base_speed * dash_speed_multiplier
	dash_started.emit()


## Adds an instantaneous knockback force to the entity.
## Multiple calls accumulate (e.g. hit from two sources at once).
func apply_knockback(force_vector: Vector2) -> void:
	_knockback_velocity += force_vector


## Returns true while the entity is actively dashing.
func is_dashing() -> bool:
	return _is_dashing


## Returns true when the entity is allowed to initiate a new dash.
func can_dash() -> bool:
	return _dash_cooldown_timer <= 0.0 and not _is_dashing
