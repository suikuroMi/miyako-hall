# hazard_zone.gd
# Environmental tilemap hazard (Spikes, Poison Bog, Lava Pit, Blizzard Chasm).
# Applies periodic damage, elemental status effects, or movement slow to entities inside.

class_name HazardZone
extends Area2D

# ---------------------------------------------------------------------------
# Enums & Exports
# ---------------------------------------------------------------------------

enum HazardType {
	SPIKES,
	POISON_BOG,
	LAVA,
	BLIZZARD_CHASM
}

@export var hazard_type: HazardType = HazardType.SPIKES
@export var damage_per_tick: float = 8.0
@export var tick_interval: float = 0.8
@export var slow_multiplier: float = 0.6  # 40% slow for bogs/chasms
@export var is_periodic_cycle: bool = false # E.g., spikes retracting and extending
@export var active_cycle_time: float = 2.0
@export var inactive_cycle_time: float = 1.5

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------

var _is_hazard_active: bool = true
var _cycle_timer: float = 0.0
var _tick_timers: Dictionary = {} # body -> float timer
var _overlapping_bodies: Array[Node2D] = []

@onready var visual_rect: ColorRect = $VisualRect
@onready var status_label: Label = $StatusLabel

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 # Layer 1 = Player, Layer 2 = Enemies

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_update_hazard_visuals()

func _physics_process(delta: float) -> void:
	if is_periodic_cycle:
		_cycle_timer += delta
		if _is_hazard_active and _cycle_timer >= active_cycle_time:
			_cycle_timer = 0.0
			_set_hazard_active(false)
		elif not _is_hazard_active and _cycle_timer >= inactive_cycle_time:
			_cycle_timer = 0.0
			_set_hazard_active(true)

	if not _is_hazard_active:
		return

	# Tick damage for overlapping bodies
	for body in _overlapping_bodies:
		if not is_instance_valid(body):
			continue

		var t: float = _tick_timers.get(body, 0.0) - delta
		if t <= 0.0:
			t = tick_interval
			_apply_hazard_effect(body)
		_tick_timers[body] = t

func _set_hazard_active(active: bool) -> void:
	_is_hazard_active = active
	if visual_rect:
		var target_alpha := 0.85 if active else 0.2
		var tween = create_tween()
		tween.tween_property(visual_rect, "modulate:a", target_alpha, 0.25)
	if status_label:
		status_label.text = "⚠️ ACTIVE" if active else "💤 SAFE"

func _apply_hazard_effect(body: Node2D) -> void:
	# Deal damage via StatsComponent or direct take_damage
	if body.has_node("StatsComponent"):
		var stats: StatsComponent = body.get_node("StatsComponent")
		stats.take_damage(damage_per_tick)
	elif body.has_method("take_damage"):
		body.take_damage(damage_per_tick)

	# Apply elemental effects if StatusEffectComponent exists
	if body.has_node("StatusEffectComponent"):
		var status: StatusEffectComponent = body.get_node("StatusEffectComponent")
		match hazard_type:
			HazardType.LAVA:
				status.apply_burn(2.5, 4.0)
			HazardType.BLIZZARD_CHASM:
				status.apply_frost(2.5, 2)
			HazardType.POISON_BOG:
				status.apply_curse(3.0)

	# Camera feedback if player is hit
	if body.is_in_group("player") and CameraManager:
		CameraManager.shake(4.0, 0.15)

func _on_body_entered(body: Node2D) -> void:
	if body not in _overlapping_bodies:
		_overlapping_bodies.append(body)
		_tick_timers[body] = 0.0 # Trigger immediate tick upon entering

func _on_body_exited(body: Node2D) -> void:
	_overlapping_bodies.erase(body)
	_tick_timers.erase(body)

func _update_hazard_visuals() -> void:
	if not visual_rect:
		return

	match hazard_type:
		HazardType.SPIKES:
			visual_rect.color = Color(0.65, 0.65, 0.7, 0.8)
			if status_label:
				status_label.text = "🗡️ SPIKES"
		HazardType.POISON_BOG:
			visual_rect.color = Color(0.2, 0.55, 0.15, 0.75)
			if status_label:
				status_label.text = "🧪 POISON BOG"
		HazardType.LAVA:
			visual_rect.color = Color(0.9, 0.3, 0.05, 0.85)
			if status_label:
				status_label.text = "🔥 SCORCHING LAVA"
		HazardType.BLIZZARD_CHASM:
			visual_rect.color = Color(0.3, 0.7, 0.95, 0.8)
			if status_label:
				status_label.text = "❄️ BLIZZARD CHASM"
