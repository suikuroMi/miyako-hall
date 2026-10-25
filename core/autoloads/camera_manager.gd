# camera_manager.gd
# Global Autoload singleton managing dynamic camera screen shake.
# Triggers on heavy hits, weapon finishers, critical strikes, and boss phase shifts.

extends Node

var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0
var _active_camera: Camera2D = null
var _original_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if not is_instance_valid(_active_camera):
			_find_camera()
			if not is_instance_valid(_active_camera):
				return

		var current_intensity: float = _shake_intensity * (_shake_timer / max(_shake_timer, 0.01))
		_active_camera.offset = _original_offset + Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)

		if _shake_timer <= 0.0:
			_active_camera.offset = _original_offset
			_shake_intensity = 0.0

## Triggers camera shake with customizable intensity and duration
func shake(intensity: float = 8.0, duration: float = 0.22) -> void:
	_find_camera()
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_timer = max(_shake_timer, duration)

func _find_camera() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		if _active_camera != cam:
			_active_camera = cam
			_original_offset = cam.offset
	else:
		var cams = get_tree().get_nodes_in_group("cameras")
		if cams.size() > 0 and cams[0] is Camera2D:
			_active_camera = cams[0]
			_original_offset = _active_camera.offset
