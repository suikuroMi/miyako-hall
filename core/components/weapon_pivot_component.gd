class_name WeaponPivotComponent
extends Node2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export var team: int = 0  # 0 = player, 1 = enemy

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal attacked(weapon_data: WeaponData)

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

var _weapon_data: WeaponData = null
var _attack_cooldown: float = 0.0
var _hitbox: HitboxComponent = null   # child node, found in _ready

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Look for a HitboxComponent child node
	_hitbox = get_node_or_null("HitboxComponent")

func _process(delta: float) -> void:
	# Count down attack cooldown
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	# Only the player pivot tracks the mouse; AI callers rotate themselves
	if get_parent() and get_parent().is_in_group("player"):
		look_at(get_global_mouse_position())

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Equip a new WeaponData resource. Resets the cooldown so the player can
## attack immediately after swapping weapons.
func equip(weapon: WeaponData) -> void:
	_weapon_data = weapon
	if _hitbox and weapon:
		_hitbox.damage = weapon.damage
		_hitbox.knockback_force = weapon.knockback_force
		_hitbox.team = team
	_attack_cooldown = 0.0   # reset so player can attack immediately

## Attempt an attack. Does nothing if no weapon is equipped or cooldown is
## still active.
func try_attack() -> void:
	if _weapon_data == null or _attack_cooldown > 0.0:
		return

	# Base cooldown from attack_speed (attacks per second)
	var actual_cooldown: float = 1.0 / _weapon_data.attack_speed

	# Apply synergy cooldown reduction when the parent character favours this
	# weapon type (checks for a stats_data property on the parent node).
	var parent = get_parent()
	if parent and "stats_data" in parent:
		var cd: CharacterData = parent.stats_data
		if cd and cd.favored_weapon == _weapon_data.weapon_type:
			actual_cooldown *= (1.0 - _weapon_data.synergy_cooldown_reduction)

	_attack_cooldown = actual_cooldown

	if _weapon_data.is_ranged:
		_fire_projectile()
	else:
		_swing_melee()

	attacked.emit(_weapon_data)

## Return the currently equipped WeaponData (may be null).
func get_weapon_data() -> WeaponData:
	return _weapon_data

## Returns true when a weapon is currently equipped.
func has_weapon() -> bool:
	return _weapon_data != null

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _fire_projectile() -> void:
	var proj_scene: PackedScene = _weapon_data.projectile_scene
	if not proj_scene:
		proj_scene = preload("res://entities/objects/bullet/bullet.tscn")

	var dmg: float = _weapon_data.damage + _weapon_data.damage_bonus
	var spd: float = 900.0
	var rng: float = _weapon_data.attack_range

	if ObjectPool and proj_scene.resource_path == "res://entities/objects/bullet/bullet.tscn":
		ObjectPool.spawn_bullet(global_position, rotation, dmg, spd, rng, team)
	else:
		var proj = proj_scene.instantiate()
		proj.global_transform = global_transform
		if "damage" in proj:
			proj.damage = dmg
		if "range" in proj:
			proj.range = rng
		if "team" in proj:
			proj.team = team
		get_tree().current_scene.add_child(proj)

func _swing_melee() -> void:
	if _hitbox == null:
		return
	_hitbox.damage = _weapon_data.damage + _weapon_data.damage_bonus
	_hitbox.knockback_force = _weapon_data.knockback_force
	_hitbox.activate(_weapon_data.swing_duration)

	# Dynamic Melee Arc Sweep:
	# Sweeps hitbox through a 100-degree cutting arc with expanding impact scale
	var swing_arc: float = 1.7
	_hitbox.rotation = -swing_arc * 0.5
	_hitbox.scale = Vector2(0.8, 0.8)
	var tween: Tween = create_tween()
	tween.tween_property(_hitbox, "rotation", swing_arc * 0.5, _weapon_data.swing_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_hitbox, "scale", Vector2(1.3, 1.3), _weapon_data.swing_duration * 0.4)
	tween.tween_property(_hitbox, "scale", Vector2(1.0, 1.0), _weapon_data.swing_duration * 0.6)

	# Animate weapon sprite if available
	var parent = get_parent()
	if parent:
		var wp_sprite = parent.get_node_or_null("WeaponSprite")
		if wp_sprite:
			var orig_rot: float = wp_sprite.rotation
			var sp_tween: Tween = create_tween()
			sp_tween.tween_property(wp_sprite, "rotation", orig_rot + 1.2, _weapon_data.swing_duration * 0.5)
			sp_tween.tween_property(wp_sprite, "rotation", orig_rot, _weapon_data.swing_duration * 0.5)
