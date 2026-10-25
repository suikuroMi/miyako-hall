# hitbox_component.gd
# Area2D that deals damage to HurtboxComponents on the opposite team.
# Attach this as a child of any attack/projectile/AoE scene.
#
# Team convention:
#   0 = player team  → hurts team 1 (enemies)
#   1 = enemy team   → hurts team 0 (player)
#
# Usage:
#   1. Add HitboxComponent as a child of the weapon / attack node.
#   2. Set `team`, `damage`, and `knockback_force` in the Inspector.
#   3. Call activate() when the attack should begin, deactivate() when done.
#      Pass a duration to activate() for automatic deactivation.

class_name HitboxComponent
extends Area2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var damage: float = 10.0
@export var knockback_force: float = 0.0
## 0 = player team, 1 = enemy team
@export var team: int = 0

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var _is_active: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	monitoring   = false   # not scanning by default
	monitorable  = false   # other areas cannot detect this hitbox when inactive
	area_entered.connect(_on_area_entered)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Enable this hitbox. If duration > 0 it automatically deactivates after
## that many seconds (useful for melee swings with a fixed active window).
func activate(duration: float = 0.0) -> void:
	_is_active  = true
	monitoring  = true
	monitorable = true

	if duration > 0.0:
		var timer: Timer = Timer.new()
		timer.wait_time   = duration
		timer.one_shot    = true
		timer.autostart   = true
		add_child(timer)
		timer.timeout.connect(deactivate)
		timer.timeout.connect(timer.queue_free)

## Disable this hitbox immediately.
func deactivate() -> void:
	_is_active  = false
	monitoring  = false
	monitorable = false

# ---------------------------------------------------------------------------
# Collision handling
# ---------------------------------------------------------------------------

func _on_area_entered(area: Area2D) -> void:
	if not _is_active:
		return

	# Only interact with HurtboxComponents on the opposing team
	if area is HurtboxComponent and area.team != team:
		area.receive_damage(damage, knockback_force, get_parent().global_position)
