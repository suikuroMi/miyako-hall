# map_transition_zone.gd
# Pokémon-style doorway / route transition Area2D.
# When the player steps inside (or presses E if prompt enabled),
# warps to target_map_path and places them at target_spawn_id.

class_name MapTransitionZone
extends Area2D

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export_file("*.tscn") var target_map_path: String = ""
@export var target_spawn_id: String = "default"
@export var transition_delay: float = 0.05
@export var require_interaction: bool = false
@export var prompt_message: String = "Press E to Enter"

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var _player_inside: bool = false
var _prompt_label: Label = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Detect Player physics body
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if require_interaction:
		_create_prompt_label()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not require_interaction:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_trigger_transition()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Internal Logic
# ---------------------------------------------------------------------------

func _create_prompt_label() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = prompt_message
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-75, -45)
	_prompt_label.custom_minimum_size = Vector2(150, 30)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
		
	_player_inside = true
	
	if require_interaction:
		if _prompt_label:
			_prompt_label.visible = true
	else:
		if transition_delay > 0.0:
			var timer := get_tree().create_timer(transition_delay)
			timer.timeout.connect(func():
				if _player_inside:
					_trigger_transition()
			)
		else:
			_trigger_transition()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if _prompt_label:
			_prompt_label.visible = false

func _trigger_transition() -> void:
	if target_map_path == "":
		push_warning("[MapTransitionZone] No target map assigned!")
		return
		
	if SceneManager:
		SceneManager.transition_to_map(target_map_path, target_spawn_id)
	elif EventBus:
		EventBus.map_transition_requested.emit(target_map_path, target_spawn_id)
