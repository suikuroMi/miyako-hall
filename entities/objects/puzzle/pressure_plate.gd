# pressure_plate.gd
# Environmental floor switch for temple & overworld puzzles.
# Depresses when stepped on by the Player or when weighted down by a PushableBoulder.

class_name PressurePlate
extends Area2D

signal plate_pressed(plate_id: String)
signal plate_released(plate_id: String)

@export var plate_id: String = "plate_01"
@export var target_gate_node: NodePath

var _occupants: Array[Node2D] = []
var is_active: bool = false

@onready var visual_rect: ColorRect = $VisualRect

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4 # Player (1) and PushableBoulder (4)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_plate_visuals(false)

func _on_body_entered(body: Node2D) -> void:
	if body not in _occupants:
		_occupants.append(body)

	if not is_active and _occupants.size() > 0:
		_set_plate_active(true)

func _on_body_exited(body: Node2D) -> void:
	_occupants.erase(body)
	if is_active and _occupants.size() == 0:
		_set_plate_active(false)

func _set_plate_active(active: bool) -> void:
	is_active = active
	_update_plate_visuals(active)

	if active:
		if AudioManager:
			AudioManager.play_sfx("purified")
		if CameraManager:
			CameraManager.shake(3.0, 0.15)
		plate_pressed.emit(plate_id)

		# If target gate is configured, trigger it
		if target_gate_node:
			var gate = get_node_or_null(target_gate_node)
			if gate and gate.has_method("open_gate"):
				gate.open_gate()
	else:
		plate_released.emit(plate_id)

func _update_plate_visuals(active: bool) -> void:
	if not visual_rect:
		return
	var target_color = Color(0.3, 0.9, 0.4, 0.9) if active else Color(0.4, 0.45, 0.5, 0.6)
	var tw = create_tween()
	tw.tween_property(visual_rect, "color", target_color, 0.15)
