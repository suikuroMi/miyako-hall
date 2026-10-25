# status_effect_component.gd
# Manages elemental afflictions (Burn, Frost, Curse) and their powerful resonance synergies.
# Attach as a child Node to any entity (Player, BaseEnemy, Boss).

class_name StatusEffectComponent
extends Node

# ---------------------------------------------------------------------------
# Enums & Signals
# ---------------------------------------------------------------------------

enum ElementType {
	NONE,
	BURN,   # Purification Flame (DoT, reduces attack)
	FROST,  # Blizzard Frost (Slows, freezes at 3 stacks)
	CURSE   # Tarot Shadow Stigma (Increases incoming crits)
}

signal effect_applied(element: ElementType, duration: float)
signal effect_expired(element: ElementType)
signal resonance_triggered(resonance_name: String, position: Vector2)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _burn_timer: float = 0.0
var _burn_tick_timer: float = 0.0
var _burn_damage_per_tick: float = 4.0

var _frost_timer: float = 0.0
var _frost_stacks: int = 0
var _freeze_timer: float = 0.0

var _curse_timer: float = 0.0

var _stats: StatsComponent = null
var _movement: MovementComponent = null
var _sprite: CanvasItem = null
var _original_modulate: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	var parent = get_parent()
	if parent:
		_stats = parent.get_node_or_null("StatsComponent")
		_movement = parent.get_node_or_null("MovementComponent")
		_sprite = parent.get_node_or_null("CharacterSprite")
		if not _sprite:
			_sprite = parent.get_node_or_null("Sprite2D")
		if _sprite:
			_original_modulate = _sprite.modulate

func _physics_process(delta: float) -> void:
	# Burn processing
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer = 0.5
			if _stats:
				_stats.take_damage(_burn_damage_per_tick)
			if _burn_timer <= 0.0:
				effect_expired.emit(ElementType.BURN)

	# Frost & Freeze processing
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		if _movement:
			_movement.base_speed = 0.0
	elif _frost_timer > 0.0:
		_frost_timer -= delta
		if _frost_timer <= 0.0:
			_frost_stacks = 0
			effect_expired.emit(ElementType.FROST)

	# Curse processing
	if _curse_timer > 0.0:
		_curse_timer -= delta
		if _curse_timer <= 0.0:
			effect_expired.emit(ElementType.CURSE)

	_update_visual_tint()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Applies an elemental affliction to the parent entity
func apply_element(element: ElementType, duration: float = 3.5, potency: float = 1.0) -> void:
	match element:
		ElementType.BURN:
			# Check for Steam Burst resonance (Frost + Burn)
			if _frost_stacks > 0 or _freeze_timer > 0.0:
				_trigger_steam_burst()
				return

			_burn_timer = duration
			_burn_tick_timer = 0.5
			_burn_damage_per_tick = 5.0 * potency
			effect_applied.emit(ElementType.BURN, duration)

		ElementType.FROST:
			# Check for Purification Shatter resonance (Curse + Frost)
			if _curse_timer > 0.0:
				_trigger_purification_shatter()
				return

			_frost_timer = duration
			_frost_stacks = mini(_frost_stacks + 1, 3)
			if _frost_stacks >= 3:
				_freeze_timer = 1.5
				_frost_stacks = 0
			effect_applied.emit(ElementType.FROST, duration)

		ElementType.CURSE:
			# Check for Infernal Stigma resonance (Burn + Curse)
			if _burn_timer > 0.0:
				_burn_damage_per_tick *= 2.2
				_trigger_resonance_fx("Infernal Stigma!", Color(0.9, 0.2, 0.9))

			_curse_timer = duration
			effect_applied.emit(ElementType.CURSE, duration)

## Returns movement speed multiplier from active elements (e.g., frost chill)
func get_speed_multiplier() -> float:
	if _freeze_timer > 0.0:
		return 0.0
	if _frost_stacks > 0:
		return max(1.0 - (0.25 * _frost_stacks), 0.3)
	return 1.0

## Returns bonus critical rate against this entity if cursed
func get_bonus_crit_rate() -> float:
	return 0.30 if _curse_timer > 0.0 else 0.0

# ---------------------------------------------------------------------------
# Elemental Resonances
# ---------------------------------------------------------------------------

func _trigger_steam_burst() -> void:
	_frost_stacks = 0
	_frost_timer = 0.0
	_freeze_timer = 0.0

	var parent = get_parent()
	var pos: Vector2 = parent.global_position if parent is Node2D else Vector2.ZERO
	resonance_triggered.emit("Steam Burst", pos)
	_trigger_resonance_fx("Steam Burst! 💥", Color(0.4, 0.8, 1.0))

	# Deal AOE damage to surrounding targets
	if parent is Node2D:
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if e != parent and is_instance_valid(e) and e is Node2D:
				if pos.distance_to(e.global_position) < 130.0:
					if e.has_method("take_damage"):
						e.take_damage(25.0)

func _trigger_purification_shatter() -> void:
	_curse_timer = 0.0
	var parent = get_parent()
	var pos: Vector2 = parent.global_position if parent is Node2D else Vector2.ZERO
	resonance_triggered.emit("Purification Shatter", pos)
	_trigger_resonance_fx("Purification Shatter! ✨", Color(0.7, 0.4, 1.0))

	if AudioManager:
		AudioManager.play_sfx("purified")

	if _stats:
		_stats.take_damage(35.0)

func _trigger_resonance_fx(text: String, color: Color) -> void:
	var parent: Node2D = get_parent() as Node2D
	if not parent or not is_inside_tree():
		return

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(-40, -50)
	parent.add_child(lbl)

	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", -75.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.finished.connect(lbl.queue_free)

func _update_visual_tint() -> void:
	if not _sprite:
		return

	if _freeze_timer > 0.0 or _frost_stacks > 0:
		_sprite.modulate = Color(0.45, 0.75, 1.3, 1.0) # Ice blue
	elif _burn_timer > 0.0:
		_sprite.modulate = Color(1.3, 0.6, 0.4, 1.0) # Flame orange
	elif _curse_timer > 0.0:
		_sprite.modulate = Color(0.85, 0.4, 1.3, 1.0) # Tarot purple
	else:
		_sprite.modulate = _original_modulate
