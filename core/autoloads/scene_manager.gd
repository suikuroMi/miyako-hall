# scene_manager.gd
# Global Autoload singleton managing seamless scene/map transitions,
# Pokémon-style door/route warps, screen fades, and player positioning at spawn points.

extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal transition_started(target_map_path: String)
signal transition_completed(target_map_path: String)

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var is_transitioning: bool = false
var _overlay: ColorRect
var _anim_tween: Tween
var _pending_spawn_id: String = ""

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 128 # Always draw on top of game and HUD
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep running even if game is paused
	
	_build_overlay()
	
	if EventBus:
		EventBus.map_transition_requested.connect(_on_map_transition_requested)

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	add_child(_overlay)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Transitions from current scene to target_map_path, positioning the player
## at the SpawnPoint with matching spawn_id.
func transition_to_map(target_map_path: String, spawn_id: String = "default", duration: float = 0.3) -> void:
	if is_transitioning:
		return
	if target_map_path == "" or not ResourceLoader.exists(target_map_path):
		push_warning("[SceneManager] Invalid map path: " + target_map_path)
		return
		
	is_transitioning = true
	_pending_spawn_id = spawn_id
	transition_started.emit(target_map_path)
	
	# Block input during transition
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Fade out to black
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(_overlay, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _anim_tween.finished
	
	# Change the scene
	var err := get_tree().change_scene_to_file(target_map_path)
	if err != OK:
		push_error("[SceneManager] Failed to load scene: " + target_map_path)
		_overlay.color.a = 0.0
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_transitioning = false
		return
		
	# Wait for scene tree to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Place player at spawn point
	_position_player_at_spawn(_pending_spawn_id)
	
	# Fade in from black
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(_overlay, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _anim_tween.finished
	
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	transition_completed.emit(target_map_path)

# ---------------------------------------------------------------------------
# Internal Helpers
# ---------------------------------------------------------------------------

func _position_player_at_spawn(spawn_id: String) -> void:
	var player: Node2D = get_tree().root.find_child("Player", true, false) as Node2D
	if not is_instance_valid(player):
		return
		
	var spawn_points: Array[Node] = get_tree().get_nodes_in_group("spawn_points")
	var target_point: Node2D = null
	
	# Try finding exact spawn_id
	for sp in spawn_points:
		if sp is Node2D and "spawn_id" in sp and sp.spawn_id == spawn_id:
			target_point = sp
			break
			
	# Fallback to first spawn point if not found
	if not target_point and spawn_points.size() > 0:
		target_point = spawn_points[0] as Node2D
		
	if target_point:
		player.global_position = target_point.global_position
		if "facing_direction" in target_point and "last_horizontal_direction" in player:
			var facing: Vector2 = target_point.facing_direction
			if facing.x != 0.0:
				player.last_horizontal_direction = sign(facing.x)

func _on_map_transition_requested(target_map_path: String, spawn_point_id: String) -> void:
	transition_to_map(target_map_path, spawn_point_id)
