# basic_chaser.gd
# Standard chasing enemy extending BaseEnemy.

class_name BasicChaser
extends BaseEnemy

func _setup_enemy() -> void:
	enemy_name = "Corrupted Spirit"
	if stats:
		stats.max_hp = 45.0
		stats.current_hp = 45.0
