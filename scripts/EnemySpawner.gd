extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_rate: float = 1.0
@export var spawn_distance: float = 750.0

var _timer: float = 0.0
var _player: Node2D

func _ready():
	_player = get_tree().root.find_child("Player", true, false)

func _process(delta):
	if not _player:
		return

	_timer += delta
	if _timer >= spawn_rate:
		spawn_enemy()
		_timer = 0

func spawn_enemy():
	var angle = randf_range(0, PI * 2)
	var offset = Vector2(cos(angle), sin(angle)) * spawn_distance
	var spawn_pos = _player.global_position + offset

	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	get_tree().current_scene.add_child(enemy)
