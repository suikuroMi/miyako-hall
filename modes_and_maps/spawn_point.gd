# spawn_point.gd
# Marker2D marking player entry points into maps/routes.
class_name SpawnPoint
extends Marker2D

@export var spawn_id: String = "default"
@export var facing_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("spawn_points")
