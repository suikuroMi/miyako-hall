# dialogue_box.gd
# Polished, RPG-style dialogue box with speaker name, typewriter effect,
# avatar portraits, and input progression.

class_name DialogueBox
extends Control

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal dialogue_finished()

# ---------------------------------------------------------------------------
# UI References
# ---------------------------------------------------------------------------
@onready var panel: PanelContainer = $PanelContainer
@onready var speaker_label: Label = $PanelContainer/Margin/HBox/VBox/SpeakerName
@onready var content_label: RichTextLabel = $PanelContainer/Margin/HBox/VBox/ContentText
@onready var portrait_rect: TextureRect = $PanelContainer/Margin/HBox/Portrait
@onready var continue_indicator: Label = $PanelContainer/Margin/HBox/VBox/ContinueHint

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var _lines: Array = []
var _current_line_idx: int = -1
var _is_typing: bool = false
var _typewriter_speed: float = 0.025 # seconds per character
var _typewriter_tween: Tween

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if EventBus:
		EventBus.dialogue_started.connect(start_dialogue)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER:
			_handle_advance()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_advance()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func start_dialogue(lines: Array) -> void:
	if lines.size() == 0:
		return

	_lines = lines
	_current_line_idx = -1
	visible = true
	_advance_line()

# ---------------------------------------------------------------------------
# Internal Flow
# ---------------------------------------------------------------------------

func _handle_advance() -> void:
	if _is_typing:
		# Skip typewriter and instantly show full text
		if _typewriter_tween and _typewriter_tween.is_valid():
			_typewriter_tween.kill()
		content_label.visible_ratio = 1.0
		_is_typing = false
		continue_indicator.visible = true
	else:
		_advance_line()

func _advance_line() -> void:
	_current_line_idx += 1

	if _current_line_idx >= _lines.size():
		_close_dialogue()
		return

	var line_data: Dictionary = _lines[_current_line_idx]
	var speaker: String = line_data.get("speaker", "???")
	var text: String = line_data.get("text", "")
	var portrait: Texture2D = line_data.get("portrait", null)

	speaker_label.text = speaker
	content_label.text = text
	content_label.visible_ratio = 0.0
	continue_indicator.visible = false

	if portrait:
		portrait_rect.texture = portrait
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false

	if EventBus:
		EventBus.dialogue_advanced.emit(_current_line_idx, line_data)

	# Start typewriter effect
	_is_typing = true
	var char_count: int = text.length()
	var duration: float = max(char_count * _typewriter_speed, 0.4)

	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()

	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(content_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.finished.connect(func():
		_is_typing = false
		continue_indicator.visible = true
	)

func _close_dialogue() -> void:
	visible = false
	_lines = []
	_current_line_idx = -1
	dialogue_finished.emit()
	if EventBus:
		EventBus.dialogue_ended.emit()
