# photo_mode.gd
# Pause-action cinematic photo mode.
# Hides gameplay HUD, allows free camera zoom, applies dramatic color filters,
# and captures screenshots of chaotic bullet-hell action!
# Toggled via [P] hotkey or Pause menu.

extends CanvasLayer

@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var filter_rect: ColorRect = $FilterRect
@onready var filter_btn: OptionButton = $ControlsPanel/VBox/FilterRow/FilterOption
@onready var zoom_slider: HSlider = $ControlsPanel/VBox/ZoomRow/ZoomSlider
@onready var snap_btn: Button = $ControlsPanel/VBox/BtnRow/SnapBtn
@onready var exit_btn: Button = $ControlsPanel/VBox/BtnRow/ExitBtn
@onready var shutter_flash: ColorRect = $ShutterFlash

var _camera: Camera2D = null
var _original_zoom: Vector2 = Vector2(2.0, 2.0)
var _is_active: bool = false

const FILTERS: Dictionary = {
	0: Color(1.0, 1.0, 1.0, 0.0), # Normal
	1: Color(0.9, 0.75, 0.5, 0.25), # Vintage Warm
	2: Color(0.2, 0.8, 1.0, 0.2), # Cyber Azure
	3: Color(1.0, 0.2, 0.4, 0.3), # False Moon Crimson
	4: Color(0.1, 0.1, 0.1, 0.45) # Noir Monochrome
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if shutter_flash:
		shutter_flash.visible = false

	if filter_btn:
		filter_btn.clear()
		filter_btn.add_item("None (Natural)", 0)
		filter_btn.add_item("Vintage Warm", 1)
		filter_btn.add_item("Cyber Azure", 2)
		filter_btn.add_item("False Moon Crimson", 3)
		filter_btn.add_item("Noir Monochrome", 4)
		filter_btn.item_selected.connect(_on_filter_selected)

	if zoom_slider:
		zoom_slider.value_changed.connect(_on_zoom_changed)

	if snap_btn:
		snap_btn.pressed.connect(capture_photo)

	if exit_btn:
		exit_btn.pressed.connect(toggle_photo_mode)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_P:
			toggle_photo_mode()
			get_viewport().set_input_as_handled()

func toggle_photo_mode() -> void:
	_is_active = not _is_active
	visible = _is_active

	var player = get_tree().root.find_child("Player", true, false)
	if is_instance_valid(player) and player.has_node("Camera2D"):
		_camera = player.get_node("Camera2D")

	if _is_active:
		get_tree().paused = true
		if _camera:
			_original_zoom = _camera.zoom
			if zoom_slider:
				zoom_slider.value = _camera.zoom.x
	else:
		get_tree().paused = false
		if _camera:
			_camera.zoom = _original_zoom

func _on_filter_selected(index: int) -> void:
	if filter_rect and FILTERS.has(index):
		filter_rect.color = FILTERS[index]

func _on_zoom_changed(val: float) -> void:
	if _camera:
		_camera.zoom = Vector2(val, val)

func capture_photo() -> void:
	# Hide photo UI controls briefly during capture
	controls_panel.visible = false

	# Play shutter flash
	if shutter_flash:
		shutter_flash.visible = true
		shutter_flash.color = Color(1.0, 1.0, 1.0, 0.9)
		var tw := shutter_flash.create_tween()
		tw.tween_property(shutter_flash, "color:a", 0.0, 0.25)
		tw.finished.connect(func():
			shutter_flash.visible = false
			controls_panel.visible = true
		)

	if AudioManager:
		AudioManager.play_sfx("coin")

	# Save screenshot
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var filename := "user://photo_%d.png" % Time.get_unix_time_from_system()
	img.save_png(filename)
