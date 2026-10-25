# minimap.gd
# Top-Right Minimap controller with Zoom (+/-), Toggle/Close (M), and decoupled target tracking.

extends Control

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var zoom_step: float = 0.2
@export var min_zoom: float = 0.25
@export var max_zoom: float = 1.5

# ---------------------------------------------------------------------------
# UI References
# ---------------------------------------------------------------------------
@onready var map_panel: Control = $MapPanel
@onready var sub_viewport: SubViewport = $MapPanel/Border/SubViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $MapPanel/Border/SubViewportContainer/SubViewport/Camera2D
@onready var close_button: Button = $MapPanel/ControlButtons/CloseButton
@onready var zoom_in_button: Button = $MapPanel/ControlButtons/ZoomInButton
@onready var zoom_out_button: Button = $MapPanel/ControlButtons/ZoomOutButton
@onready var toggle_pill_button: Button = $TogglePillButton

var _player_ref: Node2D = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_button:
		close_button.pressed.connect(toggle_minimap)
	if zoom_in_button:
		zoom_in_button.pressed.connect(zoom_in)
	if zoom_out_button:
		zoom_out_button.pressed.connect(zoom_out)
	if toggle_pill_button:
		toggle_pill_button.pressed.connect(toggle_minimap)
		toggle_pill_button.visible = false

	# Re-acquire target and viewport world when scene transitions occur
	if SceneManager:
		SceneManager.transition_completed.connect(func(_map): _setup_minimap_world())

	call_deferred("_setup_minimap_world")

func _setup_minimap_world() -> void:
	if sub_viewport:
		var root_viewport = get_tree().root.get_viewport()
		if root_viewport:
			sub_viewport.world_2d = root_viewport.world_2d

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0] as Node2D

func _process(_delta: float) -> void:
	if not is_instance_valid(_player_ref):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player_ref = players[0] as Node2D
		return

	if minimap_camera and is_instance_valid(_player_ref):
		minimap_camera.global_position = _player_ref.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			toggle_minimap()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public Controls
# ---------------------------------------------------------------------------

func zoom_in() -> void:
	if not minimap_camera:
		return
	var new_z = minimap_camera.zoom + Vector2(zoom_step, zoom_step)
	minimap_camera.zoom = new_z.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

func zoom_out() -> void:
	if not minimap_camera:
		return
	var new_z = minimap_camera.zoom - Vector2(zoom_step, zoom_step)
	minimap_camera.zoom = new_z.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

func toggle_minimap() -> void:
	if map_panel:
		map_panel.visible = not map_panel.visible
		if toggle_pill_button:
			toggle_pill_button.visible = not map_panel.visible
