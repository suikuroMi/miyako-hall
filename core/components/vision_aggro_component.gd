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

## Brief hesitation (seconds) upon first spotting the player with the "!" indicator.
@export var alert_delay: float = 0.3

## How long (seconds) the enemy searches the player's last known position before giving up.
@export var investigate_duration: float = 2.0

## How often (seconds) the aggro check runs. Lower = more responsive but pricier.
@export var update_interval: float = 0.1

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the enemy first spots the player and enters ALERT state ("!").
signal alert_triggered(player: Node2D)

## Emitted when the player enters detection range and the chase begins.
signal aggro_gained(player: Node2D)

## Emitted when player escapes sight and enemy investigates last known spot ("?").
signal investigating_started(last_known_pos: Vector2)

## Emitted when the player escapes and the enemy stops chasing / searching.
signal aggro_lost

# ---------------------------------------------------------------------------
# Enum
# ---------------------------------------------------------------------------

enum AggroState { IDLE, ALERT, CHASING, INVESTIGATING }

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

var state: AggroState = AggroState.IDLE
var _target: Node2D = null
var _check_timer: float = 0.0
var _alert_timer: float = 0.0
var _investigate_timer: float = 0.0
var _last_known_position: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Attempt to locate the player immediately.
	_find_player()

func _physics_process(delta: float) -> void:
	# Handle state-specific countdowns
	if state == AggroState.ALERT:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			state = AggroState.CHASING
			aggro_gained.emit(_target)
			EventBus.aggro_state_changed.emit(true)

	elif state == AggroState.CHASING:
		if is_instance_valid(_target):
			_last_known_position = _target.global_position

	elif state == AggroState.INVESTIGATING:
		_investigate_timer -= delta
		var dist_to_last: float = get_parent().global_position.distance_to(_last_known_position)
		if _investigate_timer <= 0.0 or dist_to_last < 25.0:
			state = AggroState.IDLE
			aggro_lost.emit()
			EventBus.aggro_state_changed.emit(false)

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
	var effective_detection_radius: float = detection_radius
	if _target.has_meta("is_stealthed") and _target.get_meta("is_stealthed"):
		effective_detection_radius *= 0.35

	match state:
		AggroState.IDLE:
			if dist <= effective_detection_radius:
				state = AggroState.ALERT
				_alert_timer = alert_delay
				_last_known_position = _target.global_position
				_show_indicator("!", Color(1.0, 0.25, 0.25))
				alert_triggered.emit(_target)

		AggroState.CHASING:
			if dist > lose_sight_radius:
				state = AggroState.INVESTIGATING
				_investigate_timer = investigate_duration
				_show_indicator("?", Color(1.0, 0.85, 0.2))
				investigating_started.emit(_last_known_position)

		AggroState.INVESTIGATING:
			if dist <= effective_detection_radius:
				state = AggroState.ALERT
				_alert_timer = alert_delay * 0.5
				_last_known_position = _target.global_position
				_show_indicator("!", Color(1.0, 0.25, 0.25))
				alert_triggered.emit(_target)

## Spawns a lightweight animated floating alert bubble above the parent entity
func _show_indicator(symbol: String, color: Color) -> void:
	var parent: Node2D = get_parent() as Node2D
	if not parent or not is_inside_tree():
		return

	var bubble := Label.new()
	bubble.text = symbol
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.add_theme_font_size_override("font_size", 16)
	bubble.add_theme_color_override("font_color", color)
	bubble.position = Vector2(-12, -45)
	bubble.scale = Vector2(0.5, 0.5)

	parent.add_child(bubble)

	var tween := bubble.create_tween()
	tween.tween_property(bubble, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bubble, "position:y", -55.0, 0.35)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.2)
	tween.finished.connect(bubble.queue_free)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the player Node2D while chasing, or null when idle / searching.
func get_target() -> Node2D:
	if state == AggroState.CHASING and is_instance_valid(_target):
		return _target
	return null

## Returns true when actively chasing the player.
func is_chasing() -> bool:
	return state == AggroState.CHASING

## Returns true during the brief alert hesitation window ("!").
func is_alert() -> bool:
	return state == AggroState.ALERT

## Returns true when searching the player's last known location ("?").
func is_investigating() -> bool:
	return state == AggroState.INVESTIGATING

## Returns the player's last known location.
func get_last_known_position() -> Vector2:
	return _last_known_position

## Returns a normalised direction vector pointing toward target or last known spot.
func get_direction_to_target() -> Vector2:
	var parent: Node2D = get_parent() as Node2D
	if not parent:
		return Vector2.ZERO

	if state == AggroState.CHASING and is_instance_valid(_target):
		return parent.global_position.direction_to(_target.global_position)
	elif state == AggroState.INVESTIGATING:
		return parent.global_position.direction_to(_last_known_position)

	return Vector2.ZERO
