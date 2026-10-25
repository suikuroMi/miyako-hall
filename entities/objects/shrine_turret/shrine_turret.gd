# shrine_turret.gd
# Spiritual ward turret positioned in Kamikitakuni Shrine hub.
# Automatically scans for hostile Stigmata invaders and fires purifying energy bolts.

class_name ShrineTurret
extends Node2D

@export var fire_range: float = 380.0
@export var fire_interval: float = 2.0
@export var damage: float = 22.0

var _fire_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_scan_and_fire()

func _scan_and_fire() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var target: Node2D = null
	var min_dist: float = fire_range

	for e in enemies:
		if is_instance_valid(e) and e is Node2D:
			var d: float = global_position.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				target = e

	if target:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		var rot: float = dir.angle()

		if ObjectPool:
			ObjectPool.spawn_bullet(global_position, rot, damage, 850.0, 500.0, 0)
		else:
			var bullet_scene: PackedScene = preload("res://entities/objects/bullet/bullet.tscn")
			var b = bullet_scene.instantiate()
			b.global_position = global_position
			b.rotation = rot
			b.damage = damage
			b.team = 0
			get_tree().current_scene.add_child(b)

		if AudioManager:
			AudioManager.play_sfx("coin")
