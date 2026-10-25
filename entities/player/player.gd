# player.gd
# Main player controller. Extends CharacterBody2D.
#
# Architecture notes:
#   - All HP / EXP / level / stat data lives in the StatsComponent child node.
#   - This script acts as a BRIDGE: it wraps StatsComponent calls and re-emits
#     local signals so that health_bar.gd and level_up_cards.gd keep working
#     without modification during the transition to full EventBus coupling.
#   - StatsComponent MUST be added as a child node named "StatsComponent"
#     in player.tscn via the Godot Editor.
#   - EventBus MUST be registered as an autoload named "EventBus".
#
# Visual scene notes:
#   - The player's AnimationPlayer and AnimatedSprite2D live inside a child
#     scene (character_visual_scene from CharacterData). They are dynamically
#     bound in switch_character(). @onready only covers permanent nodes.
#   - _anim_player uses library paths: anim_library + "/walk_right" etc.
#   - _weapon_sprite is a permanent Sprite2D child named "WeaponSprite".

extends CharacterBody2D

# ---------------------------------------------------------------------------
# Local signals (bridge layer — downstream UIs connect here)
# ---------------------------------------------------------------------------
signal health_changed(current_hp: float, max_hp: float)
signal exp_changed(current_exp: int, exp_to_next_level: int, level: int)
signal stats_changed()
signal level_up_choices_changed(pending_choices: int)

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var stats_data: CharacterData = null

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var equipped_weapon: Resource = null
var last_horizontal_direction: float = 1.0
var anim_library: String = ""
var _is_in_dialogue: bool = false

# ---------------------------------------------------------------------------
# Permanent child references (must exist in player.tscn)
# ---------------------------------------------------------------------------
@onready var stats: StatsComponent = $StatsComponent
@onready var movement: MovementComponent = get_node_or_null("MovementComponent")
@onready var _weapon_sprite: Sprite2D = $WeaponSprite
@onready var skill_caster: SkillCasterComponent = get_node_or_null("SkillCasterComponent")

# ---------------------------------------------------------------------------
# Dynamic visual references (bound when switch_character() is called)
# These live inside the character_visual_scene instance, not directly in
# player.tscn, so they cannot use @onready.
# ---------------------------------------------------------------------------
var _animated_sprite: AnimatedSprite2D = null
var _anim_player: AnimationPlayer = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("player")

	if not skill_caster:
		skill_caster = get_node_or_null("SkillCasterComponent")

	if stats_data:
		switch_character(stats_data)
	else:
		# Fallback so stats don't crash if no data is assigned in editor
		add_to_group("player")

	# --- Bridge connections -------------------------------------------------
	# Forward StatsComponent's local signal so level_up_cards.gd still works.
	stats.level_up_choices_changed.connect(_on_stats_level_up_choices_changed)

	# Forward EventBus HP/EXP changes as local signals for health_bar.gd etc.
	EventBus.player_hp_changed.connect(_on_eventbus_hp_changed)
	EventBus.player_exp_changed.connect(_on_eventbus_exp_changed)

	# Connect EventBus weapon_equipped to forward to WeaponPivotComponent if present
	EventBus.weapon_equipped.connect(_on_weapon_equipped)

	# Dialogue handling: pause player action during conversations
	EventBus.dialogue_started.connect(func(_lines): _is_in_dialogue = true)
	EventBus.dialogue_ended.connect(func(): _is_in_dialogue = false)

# ---------------------------------------------------------------------------
# Bridge callbacks (EventBus -> local signals)
# ---------------------------------------------------------------------------

func _on_eventbus_hp_changed(current_hp: float, max_hp: float) -> void:
	health_changed.emit(current_hp, max_hp)

func _on_eventbus_exp_changed(current_exp: int, exp_to_next_level: int, level: int) -> void:
	exp_changed.emit(current_exp, exp_to_next_level, level)

func _on_stats_level_up_choices_changed(pending: int) -> void:
	level_up_choices_changed.emit(pending)

## Receives EventBus.weapon_equipped and forwards to WeaponPivotComponent
## (node name "WeaponPivot") if one exists on this player.
func _on_weapon_equipped(weapon_resource: Resource) -> void:
	var pivot = get_node_or_null("WeaponPivot")
	if pivot and pivot.has_method("equip"):
		pivot.equip(weapon_resource)

# ---------------------------------------------------------------------------
# Character switching
# ---------------------------------------------------------------------------

## Hot-swap the player's CharacterData (e.g. from a character-select screen
## or when first loading). Replaces the visual scene and re-initialises stats.
func switch_character(new_character_data: CharacterData) -> void:
	if new_character_data == null:
		return

	stats_data = new_character_data

	# 1. Remove any existing visual scene
	for child in get_children():
		if child.is_in_group("character_visuals"):
			child.free()

	# 2. Instance the new visual scene and bind dynamic references
	_animated_sprite = null
	_anim_player = null
	anim_library = ""

	if stats_data.character_visual_scene:
		var visuals = stats_data.character_visual_scene.instantiate()
		visuals.add_to_group("character_visuals")
		add_child(visuals)

		if visuals.has_node("AnimatedSprite2D"):
			_animated_sprite = visuals.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if visuals.has_node("AnimationPlayer"):
			_anim_player = visuals.get_node("AnimationPlayer") as AnimationPlayer

	# 3. Resolve animation library name
	anim_library = stats_data.anim_library if stats_data.anim_library != "" \
		else stats_data.id + "_animation"

	# 4. Re-initialise stats from resource
	stats.initialize_from_data(stats_data)

	# 4b. Load skills into SkillCasterComponent if present
	if skill_caster:
		skill_caster.load_from_character_data(stats_data)

	# 5. Notify bridge listeners
	health_changed.emit(stats.current_hp, stats.max_hp)
	stats_changed.emit()

	if not is_in_group("player"):
		add_to_group("player")

# ---------------------------------------------------------------------------
# Movement & physics
# ---------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _is_in_dialogue:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		if direction.x != 0.0:
			last_horizontal_direction = sign(direction.x)

	if movement:
		movement.base_speed = get_movement_speed()
		velocity = movement.get_full_velocity(direction)
	else:
		velocity = direction * get_movement_speed()

	move_and_slide()

	_update_animation(direction)

func _update_animation(direction: Vector2) -> void:
	if not is_instance_valid(_anim_player) or anim_library == "":
		return

	if direction != Vector2.ZERO:
		if last_horizontal_direction < 0.0:
			_anim_player.play(anim_library + "/walk_left")
		else:
			_anim_player.play(anim_library + "/walk_right")
		if _weapon_sprite:
			_weapon_sprite.position.x = -8 if direction.x < 0.0 else 8
	else:
		if last_horizontal_direction < 0.0:
			_anim_player.play(anim_library + "/idle_left")
		else:
			_anim_player.play(anim_library + "/idle_right")

## Dedicated dash skill (Space / Shift)
func dash() -> void:
	if not movement:
		movement = get_node_or_null("MovementComponent")
	if not movement or not movement.can_dash():
		return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.is_zero_approx():
		direction = Vector2(last_horizontal_direction, 0.0)
	else:
		direction = direction.normalized()

	movement.base_speed = get_movement_speed()
	movement.try_dash(direction)

# ---------------------------------------------------------------------------
# Input (debug & placeholder attack)
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _is_in_dialogue:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var pivot = get_node_or_null("WeaponPivot")
		if pivot and pivot.has_method("try_attack"):
			pivot.try_attack()
		else:
			_attack_with_placeholder()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_SHIFT:
			dash()
			get_viewport().set_input_as_handled()
			return

		match event.physical_keycode:
			KEY_1:
				var mio_res = load("res://data/characters/ookami_mio.tres")
				if mio_res:
					switch_character(mio_res)
			KEY_H:
				take_damage(10.0)
			KEY_J:
				heal(10.0)
			KEY_K:
				add_experience(25)
			KEY_Q:
				if skill_caster:
					skill_caster.cast_skill("Q")
			KEY_E:
				if skill_caster:
					skill_caster.cast_skill("E")
			KEY_R:
				if skill_caster:
					skill_caster.cast_skill("R")

func _attack_with_placeholder() -> void:
	# Temporary melee attack — damages training dummies in a cone toward cursor.
	# Replace with HitboxComponent + skill system in Module 3/5.
	var aim_direction := get_global_mouse_position() - global_position
	if aim_direction.is_zero_approx():
		return
	aim_direction = aim_direction.normalized()
	var attack_range := 120.0
	var min_dot := cos(deg_to_rad(65.0))
	var damage := get_attack_damage()
	for dummy in get_tree().get_nodes_in_group("training_dummies"):
		if not is_instance_valid(dummy) or not dummy.has_method("take_damage"):
			continue
		var offset: Vector2 = dummy.global_position - global_position
		if offset.length() <= attack_range and aim_direction.dot(offset.normalized()) >= min_dot:
			dummy.take_damage(int(damage))

# ---------------------------------------------------------------------------
# Weapon management
# ---------------------------------------------------------------------------

func equip_weapon(data: Resource) -> void:
	equipped_weapon = data
	if _weapon_sprite and data and "texture" in data:
		_weapon_sprite.texture = data.texture
	elif _weapon_sprite:
		_weapon_sprite.texture = null
	EventBus.weapon_equipped.emit(data)
	# Forward to WeaponPivotComponent if present and data is a WeaponData resource
	var pivot = get_node_or_null("WeaponPivot")
	if pivot and pivot.has_method("equip") and data is WeaponData:
		pivot.equip(data)
	stats_changed.emit()

func unequip_weapon() -> void:
	equipped_weapon = null
	if _weapon_sprite:
		_weapon_sprite.texture = null
	EventBus.weapon_equipped.emit(null)
	stats_changed.emit()

# ---------------------------------------------------------------------------
# Stat accessors (delegate to StatsComponent)
# ---------------------------------------------------------------------------

func get_movement_speed() -> float:
	if stats:
		return 180.0 + (stats.get_total_speed(equipped_weapon) * 2.5)
	return 240.0

func get_attack_damage() -> float:
	return stats.get_total_attack(equipped_weapon)

func get_intelligence() -> float:
	return stats.stat_intelligence

# ---------------------------------------------------------------------------
# Damage / healing / experience (thin wrappers — StatsComponent does the work)
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> void:
	stats.take_damage(amount)

func heal(amount: float) -> void:
	stats.heal(amount)

func add_experience(amount: int) -> void:
	stats.add_experience(amount)

func apply_level_up_choice(choice_id: String) -> void:
	stats.apply_card_upgrade(choice_id)

func apply_card_resource(card: CardData) -> void:
	if stats:
		stats.apply_card_resource(card)

# ---------------------------------------------------------------------------
# Compatibility shims (used by spawner / old UI that reads player vars directly)
# ---------------------------------------------------------------------------

# These computed properties let old code like `_player.level` and
# `_player.current_exp` still work without breaking changes.
var level: int:
	get: return stats.level if stats else 1

var current_exp: int:
	get: return stats.current_exp if stats else 0

var exp_to_next_level: int:
	get: return stats.exp_to_next_level if stats else 100

var pending_level_up_choices: int:
	get: return stats.pending_level_up_choices if stats else 0

var health: float:
	get: return stats.current_hp if stats else 0.0

var max_health: float:
	get: return stats.max_hp if stats else 100.0

var stat_damage: float:
	get: return stats.stat_attack if stats else 0.0

var stat_speed: float:
	get: return stats.stat_speed if stats else 100.0

var stat_intelligence: float:
	get: return stats.stat_intelligence if stats else 0.0
