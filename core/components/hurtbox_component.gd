# hurtbox_component.gd
# Area2D that receives damage from HitboxComponents.
# Add as a child of any entity that can take damage (player, enemy, boss).
#
# This node is passively detectable (monitorable = true) but does not
# actively scan for other areas (monitoring = false). HitboxComponent is
# the active scanner.
#
# Usage:
#   1. Add HurtboxComponent as a child of your entity scene.
#   2. Make sure the entity also has a child named "StatsComponent".
#   3. Set `team` to match the entity (0 = player, 1 = enemy).

class_name HurtboxComponent
extends Area2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
## 0 = player, 1 = enemy — must match the entity's role
@export var team: int = 0
## How long (seconds) the entity is invincible after being hit
@export var invincibility_duration: float = 0.5

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var _is_invincible: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	monitorable = true    # HitboxComponent can detect us
	monitoring  = false   # we don't actively scan

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by HitboxComponent when a collision is confirmed.
## source_position is used to calculate knockback direction.
func receive_damage(amount: float, knockback_force: float, source_position: Vector2) -> void:
	if _is_invincible:
		return

	# Delegate actual HP reduction to StatsComponent
	var stats: StatsComponent = get_parent().get_node_or_null("StatsComponent")
	if stats:
		stats.take_damage(amount)

	# Apply knockback to CharacterBody2D parents
	_apply_knockback(knockback_force, source_position)

	# Start invincibility window
	_start_invincibility()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _apply_knockback(knockback_force: float, source_position: Vector2) -> void:
	if knockback_force <= 0.0:
		return

	var parent = get_parent()
	if not parent is CharacterBody2D:
		return

	var direction: Vector2 = (parent.global_position - source_position).normalized()
	parent.velocity += direction * knockback_force

func _start_invincibility() -> void:
	_is_invincible = true

	var timer: Timer = Timer.new()
	timer.wait_time  = invincibility_duration
	timer.one_shot   = true
	timer.autostart  = true
	add_child(timer)
	timer.timeout.connect(_on_invincibility_expired)
	timer.timeout.connect(timer.queue_free)

func _on_invincibility_expired() -> void:
	_is_invincible = false
