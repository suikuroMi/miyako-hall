# gun.gd
# Legacy gun script — now a thin wrapper kept for backward compatibility.
# The proper weapon system uses WeaponPivotComponent directly.
# This script still powers the existing gun.tscn scene.

extends Area2D

var damage: float = 15.0   # set by WeaponPivotComponent or inspector

func _process(_delta: float) -> void:
	look_at(get_global_mouse_position())

func shoot() -> void:
	const BULLET_SCENE = preload("res://entities/objects/bullet/bullet.tscn")
	var bullet = BULLET_SCENE.instantiate()
	bullet.damage = damage
	bullet.global_transform = get_node("weaponmark/Pistol/ShootingPoint").global_transform
	get_tree().current_scene.add_child(bullet)

func _on_timer_timeout() -> void:
	shoot()
