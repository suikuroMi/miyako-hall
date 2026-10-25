# interactable_component.gd
# Universal component for interactive world entities: Shrines, Lore Tablets, NPCs,
# and Boss pre-battle / post-battle dialogue triggers.

class_name InteractableComponent
extends Area2D

# ---------------------------------------------------------------------------
# Enums & Signals
# ---------------------------------------------------------------------------
signal interacted(player: Node2D)
signal interaction_completed()

enum InteractionType {
	DIALOGUE_ONLY,
	SHRINE_BLESSING,
	LORE_SIGN,
	CUSTOM_TRIGGER
}

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export_group("Interaction Setup")
@export var interaction_type: InteractionType = InteractionType.DIALOGUE_ONLY
@export var prompt_action: String = "Inspect"
@export var prompt_key: String = "E"
@export var auto_trigger: bool = false
@export var one_shot: bool = false

@export_group("Dialogue Sequence")
## Array of Dictionaries: {"speaker": "Name", "text": "Content", "portrait": Texture2D}
@export var dialogue_lines: Array[Dictionary] = []

@export_group("Blessings & Rewards")
@export var restore_health_and_mana: bool = false
@export var shrine_coin_reward: int = 0
@export var story_flag_on_interact: String = ""

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var _player_inside: bool = false
var _cached_player: Node2D = null
var _has_triggered: bool = false
var _prompt_label: Label = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Detect Player body

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_create_floating_prompt()

func _create_floating_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = "[%s] %s" % [prompt_key, prompt_action]
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-75, -45)
	_prompt_label.custom_minimum_size = Vector2(150, 24)
	_prompt_label.visible = false
	_prompt_label.z_index = 20

	# Styling
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_prompt_label)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or auto_trigger or _has_triggered and one_shot:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			trigger_interaction(_cached_player)
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Interaction Execution
# ---------------------------------------------------------------------------

func trigger_interaction(player: Node2D = null) -> void:
	if _has_triggered and one_shot:
		return

	_has_triggered = true
	if _prompt_label:
		_prompt_label.visible = false

	# Apply rewards / blessings
	if restore_health_and_mana:
		if is_instance_valid(player):
			var stats = player.get_node_or_null("StatsComponent")
			if stats:
				stats.heal(stats.max_hp)
				if "current_mana" in stats:
					stats.current_mana = stats.max_mana
		if GameManager:
			GameManager.party_health.clear()

	if shrine_coin_reward > 0:
		if GameManager:
			GameManager.add_coins(shrine_coin_reward)

	if story_flag_on_interact != "":
		if GameManager:
			GameManager.set_story_flag(story_flag_on_interact, true)

	# Trigger Dialogue if present
	if dialogue_lines.size() > 0:
		if EventBus:
			EventBus.dialogue_started.emit(dialogue_lines)

	interacted.emit(player)

	if one_shot:
		set_physics_process(false)
		set_process_unhandled_input(false)

# ---------------------------------------------------------------------------
# Area Callbacks
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	_player_inside = true
	_cached_player = body

	if _has_triggered and one_shot:
		return

	if auto_trigger:
		trigger_interaction(body)
	else:
		if _prompt_label:
			_prompt_label.text = "[%s] %s" % [prompt_key, prompt_action]
			_prompt_label.visible = true
		if EventBus:
			EventBus.interaction_prompt_shown.emit(_prompt_label.text)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_cached_player = null
		if _prompt_label:
			_prompt_label.visible = false
		if EventBus:
			EventBus.interaction_prompt_hidden.emit()
