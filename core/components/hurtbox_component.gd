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

## Sets invincibility state directly
func set_invincible(val: bool) -> void:
	_is_invincible = val

## Returns whether the hurtbox is currently invincible
func is_invincible() -> bool:
	return _is_invincible

## Activates temporary invulnerability (e.g., during dash i-frames)
func set_invincible_for(duration: float) -> void:
	_is_invincible = true
	var timer: Timer = Timer.new()
	timer.wait_time  = duration
	timer.one_shot   = true
	timer.autostart  = true
	add_child(timer)
	timer.timeout.connect(func(): _is_invincible = false)
	timer.timeout.connect(timer.queue_free)

## Called by HitboxComponent when a collision is confirmed.
## source_position is used to calculate knockback direction.
func receive_damage(amount: float, knockback_force: float, source_position: Vector2) -> void:
	if _is_invincible:
		return

	# Delegate actual HP reduction to StatsComponent
	var stats: StatsComponent = get_parent().get_node_or_null("StatsComponent")
	if stats:
		stats.take_damage(amount)

	# Trigger visual on-hit flash and camera shake
	_trigger_hit_flash()
	var parent = get_parent()
	if parent and parent.is_in_group("player") and CameraManager:
		CameraManager.shake(9.0, 0.22)

	# Apply knockback to CharacterBody2D parents
	_apply_knockback(knockback_force, source_position)

	# Start invincibility window
	_start_invincibility()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _trigger_hit_flash() -> void:
	var parent = get_parent()
	if not parent:
		return
	var sprite: CanvasItem = parent.get_node_or_null("CharacterSprite")
	if not sprite:
		sprite = parent.get_node_or_null("Sprite2D")
	if sprite:
		var orig_mod: Color = sprite.modulate
		sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
		var tw: Tween = sprite.create_tween()
		tw.tween_property(sprite, "modulate", orig_mod, 0.12)

func _apply_knockback(knockback_force: float, source_position: Vector2) -> void:
	if knockback_force <= 0.0:
		return

	var parent = get_parent()
	if not parent:
		return

	var direction: Vector2 = (parent.global_position - source_position).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var move_comp: MovementComponent = parent.get_node_or_null("MovementComponent")
	if move_comp and move_comp.has_method("apply_knockback"):
		move_comp.apply_knockback(direction * knockback_force)
	elif parent is CharacterBody2D:
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
