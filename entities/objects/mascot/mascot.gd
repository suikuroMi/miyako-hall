# mascot.gd
# Active Support Mascot companion (Mi-chan / Spirit Fox).
# Hovers beside the active Holomember, periodically firing homing spirit orbs
# at nearby hostile entities and casting emergency heals when the player's HP drops.

class_name SupportMascot
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export var mascot_name: String = "Mi-chan"
@export var follow_distance: float = 55.0
@export var follow_speed: float = 260.0
@export var attack_interval: float = 3.5
@export var bullet_damage: float = 16.0
@export var emergency_heal_cooldown: float = 45.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _player: Node2D = null
var _attack_timer: float = 0.0
var _heal_cooldown_timer: float = 0.0
var _hover_time: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("allies")
	_find_player()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()
		if not is_instance_valid(_player):
			return

	_hover_time += delta * 3.5

	# Smoothly hover beside player
	var facing_dir: float = 1.0
	if "last_horizontal_direction" in _player:
		facing_dir = _player.last_horizontal_direction

	var desired_pos: Vector2 = _player.global_position + Vector2(-facing_dir * follow_distance, -32.0 + sin(_hover_time) * 6.0)
	var to_target: Vector2 = desired_pos - global_position

	if to_target.length() > 10.0:
		velocity = to_target.normalized() * min(follow_speed, to_target.length() * 5.0)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if sprite:
		sprite.flip_h = facing_dir < 0

	# Attack loop
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_try_support_attack()

	# Emergency heal check
	if _heal_cooldown_timer > 0.0:
		_heal_cooldown_timer -= delta
	else:
		_check_emergency_heal()

# ---------------------------------------------------------------------------
# Support Behaviors
# ---------------------------------------------------------------------------

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _try_support_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var min_dist: float = 380.0

	for e in enemies:
		if is_instance_valid(e) and e is Node2D:
			var dist: float = global_position.distance_to(e.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_enemy = e

	if closest_enemy:
		var dir: Vector2 = (closest_enemy.global_position - global_position).normalized()
		var rot: float = dir.angle()

		if ObjectPool:
			ObjectPool.spawn_bullet(global_position, rot, bullet_damage, 750.0, 600.0, 0)
		else:
			var bullet_scene: PackedScene = preload("res://entities/objects/bullet/bullet.tscn")
			var b = bullet_scene.instantiate()
			b.global_position = global_position
			b.rotation = rot
			b.damage = bullet_damage
			b.team = 0
			get_tree().current_scene.add_child(b)

		if AudioManager:
			AudioManager.play_sfx("coin")

func _check_emergency_heal() -> void:
	if not _player or not _player.has_node("StatsComponent"):
		return

	var stats: StatsComponent = _player.get_node("StatsComponent")
	if stats.current_hp > 0.0 and (stats.current_hp / stats.max_hp) <= 0.35:
		_heal_cooldown_timer = emergency_heal_cooldown
		stats.heal(30.0)

		if AudioManager:
			AudioManager.play_sfx("purified")

		_spawn_floating_text("Guardian Blessing! +30 HP 💖", Color(0.4, 1.0, 0.6))

func _spawn_floating_text(txt: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(-50, -45)
	add_child(lbl)

	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", -70.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.finished.connect(lbl.queue_free)
