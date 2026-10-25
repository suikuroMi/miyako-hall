# vision_aggro_component.gd
# VisionAggroComponent — Pokémon-style aggro detection for enemies.
#
# Maintains a two-state machine (IDLE / CHASING).
# When the player walks within `detection_radius` pixels the component
# transitions to CHASING and emits `aggro_gained`.
# When the player escapes beyond `lose_sight_radius` it returns to IDLE
# and emits `aggro_lost`.
#
# The check runs on a timer (`update_interval`) rather than every frame
# to keep CPU cost low for many enemies.
#
# EDITOR NOTES:
#   - Add as a child Node inside any enemy scene.
#   - The parent scene's root node must have a `global_position` property
#     (i.e., it must be a Node2D or derived type).
#   - Make sure EventBus has a signal: aggro_state_changed(is_chasing: bool)

class_name VisionAggroComponent extends Node

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## Radius (px) within which the enemy first spots the player.
@export var detection_radius: float = 160.0

## Radius (px) the player must exceed before the enemy gives up the chase.
## Should always be larger than detection_radius to create hysteresis.
@export var lose_sight_radius: float = 280.0

## How often (seconds) the aggro check runs. Lower = more responsive but pricier.
@export var update_interval: float = 0.1

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the player enters detection range and the chase begins.
signal aggro_gained(player: Node2D)

## Emitted when the player escapes and the enemy stops chasing.
signal aggro_lost

# ---------------------------------------------------------------------------
# Enum
# ---------------------------------------------------------------------------

enum AggroState { IDLE, CHASING }

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

var state: AggroState = AggroState.IDLE
var _target: Node2D = null
var _check_timer: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Attempt to locate the player immediately.
	_find_player()


func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = update_interval
	_check_aggro()

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]


func _check_aggro() -> void:
	# Re-attempt player lookup if the reference became invalid.
	if not is_instance_valid(_target):
		_find_player()
		if not is_instance_valid(_target):
			return

	var dist: float = get_parent().global_position.distance_to(_target.global_position)

	match state:
		AggroState.IDLE:
			if dist <= detection_radius:
				state = AggroState.CHASING
				aggro_gained.emit(_target)
				EventBus.aggro_state_changed.emit(true)

		AggroState.CHASING:
			if dist > lose_sight_radius:
				state = AggroState.IDLE
				aggro_lost.emit()
				EventBus.aggro_state_changed.emit(false)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the player Node2D while chasing, or null when idle / player gone.
func get_target() -> Node2D:
	if state == AggroState.CHASING and is_instance_valid(_target):
		return _target
	return null


## Returns true when actively chasing the player.
func is_chasing() -> bool:
	return state == AggroState.CHASING


## Returns a normalised direction vector pointing from the parent toward the
## player, or Vector2.ZERO when not chasing or player is invalid.
func get_direction_to_target() -> Vector2:
	if not is_chasing() or not is_instance_valid(_target):
		return Vector2.ZERO
	return get_parent().global_position.direction_to(_target.global_position)
