extends Area2D


func _process(_delta):
	look_at(get_global_mouse_position())


func shoot():
	const BULLET = preload("res://entities/objects/bullet/bullet.tscn")
	var new_bullet = BULLET.instantiate()
	new_bullet.global_transform = get_node("weaponmarl/Pistol/ShootingPoint").global_transform
	get_node("weaponmarl/Pistol/ShootingPoint").add_child(new_bullet)


func _on_timer_timeout() -> void:
	shoot()
