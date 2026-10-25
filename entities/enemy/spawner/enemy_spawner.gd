# enemy_spawner.gd
# EnemySpawner — spawns enemies around the player with a wave-based difficulty
# scaling system and a hard enemy cap.
#
# Features:
#   - Enemies are spawned at a random point on a circle of radius `spawn_distance`
#     centred on the player.
#   - A hard cap (`max_enemies`) prevents excessive entity counts.
#   - Every `difficulty_scale_interval` seconds the spawn rate accelerates and
#     the effective enemy cap grows (up to a ceiling of 2× max_enemies).
#   - Listens to the `defeated` signal on each spawned enemy to track the live
#     count and forward experience rewards to the player.
#
# EDITOR NOTES:
#   - Assign `enemy_scene` in the Inspector.
#   - Place this node anywhere in the scene — it adds enemies directly to
#     get_tree().current_scene so they are scene-root children.

extends Node2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

## The PackedScene to instantiate for each spawn.
@export var enemy_scene: PackedScene

## Seconds between individual spawns (decreases over time as difficulty scales).
@export var spawn_rate: float = 3.0

## Distance from the player at which enemies are spawned.
@export var spawn_distance: float = 750.0

## Absolute maximum number of simultaneously-alive enemies.
@export var max_enemies: int = 20

## Seconds between each difficulty-scaling tick.
@export var difficulty_scale_interval: float = 30.0

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

## Spawn accumulator — fires a spawn when it reaches `spawn_rate`.
var _timer: float = 0.0

## Difficulty scaling accumulator.
var _difficulty_timer: float = 0.0

## Cached player reference (re-fetched if lost).
var _player: Node2D = null

## Effective enemy cap (grows with each difficulty tick).
var _current_max_enemies: int = 0

## Count of living enemies spawned by this spawner.
var _active_enemy_count: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_find_player()
	_current_max_enemies = max_enemies


func _process(delta: float) -> void:
	# Re-attempt player lookup if the reference became invalid.
	if not is_instance_valid(_player):
		_find_player()
		if not is_instance_valid(_player):
			return

	# --- Difficulty scaling ---
	_difficulty_timer += delta
	if _difficulty_timer >= difficulty_scale_interval:
		_difficulty_timer = 0.0
		# Shorten the spawn interval, clamped to a minimum of 0.5 s.
		spawn_rate = max(spawn_rate * 0.9, 0.5)
		# Raise the active cap by 2, but never exceed 2× the inspector value.
		_current_max_enemies = min(_current_max_enemies + 2, max_enemies * 2)

	# Hard cap: do not spawn more enemies than the current limit.
	if _active_enemy_count >= _current_max_enemies:
		return

	# --- Spawn timing ---
	_timer += delta
	if _timer >= spawn_rate:
		_timer = 0.0
		_spawn_enemy()

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _spawn_enemy() -> void:
	if enemy_scene == null:
		push_warning("EnemySpawner: enemy_scene is not assigned.")
		return

	# Pick a random point on a circle around the player.
	var angle: float = randf_range(0.0, TAU)
	var spawn_pos: Vector2 = _player.global_position + Vector2(cos(angle), sin(angle)) * spawn_distance

	# Instantiate and configure the enemy (pooled if ObjectPool available).
	var enemy: Node = ObjectPool.spawn(enemy_scene) if ObjectPool else enemy_scene.instantiate()
	enemy.global_position = spawn_pos

	# Listen for defeat so we can decrement the counter and reward the player.
	if enemy.has_signal("defeated") and not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)
	_active_enemy_count += 1

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

func _on_enemy_defeated(exp_amount: int) -> void:
	_active_enemy_count = max(_active_enemy_count - 1, 0)

	if GameManager:
		GameManager.register_enemy_kill()

	# Forward the experience reward to the player if it supports it.
	if is_instance_valid(_player) and _player.has_method("add_experience"):
		_player.add_experience(exp_amount)
