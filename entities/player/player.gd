extends CharacterBody2D

@export var stats_data: CharacterData = null

signal health_changed(current_health: int, max_health: int)
signal exp_changed(current_exp: int, exp_to_next_level: int, level: int)
signal level_changed(level: int)
signal level_up_choices_changed(pending_choices: int)
signal stats_changed(damage: int, speed: int, intelligence: int, max_health: int)

var health: int
var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 100
var pending_level_up_choices: int = 0

# --- Live Character Properties ---
var max_health: int
var base_speed: float
var stat_speed: int
var stat_damage: int
var stat_intelligence: int
var anim_library: String

# --- Equipment Data Slots ---
var equipped_weapon: Resource = null

# --- Dynamic Node References (Bound to the active character instance) ---
var _animated_sprite: AnimatedSprite2D = null
var _anim_player: AnimationPlayer = null

# --- Permanent Node References ---
@onready var _weapon_sprite: Sprite2D = $WeaponSprite

var last_horizontal_direction: float = 1.0 

func _ready():
	if stats_data:
		switch_character(stats_data)
	else:
		health = 100
		max_health = 100
		add_to_group("player")

func switch_character(new_character_data: CharacterData) -> void:
	if not new_character_data:
		return
		
	stats_data = new_character_data
	
	# 1. Clear out any existing visual character scenes immediately
	for child in get_children():
		if child.is_in_group("character_visuals"):
			child.free()
			
	# 2. Extract and assign the raw stats from the resource
	base_speed = stats_data.base_speed
	max_health = int(stats_data.base_health)
	stat_damage = int(stats_data.base_power)
	stat_speed = int(stats_data.base_speed)
	stat_intelligence = stats_data.base_intelligence
	anim_library = stats_data.anim_library if stats_data.anim_library != "" else stats_data.id + "_animation"
	
	# 3. Instance the visual scene package natively as a child
	if stats_data.character_visual_scene:
		var visuals_instance = stats_data.character_visual_scene.instantiate()
		visuals_instance.add_to_group("character_visuals")
		add_child(visuals_instance)
		
		# 4. Bind references directly to the newly spawned nodes inside the scene
		if visuals_instance.has_node("AnimatedSprite2D"):
			_animated_sprite = visuals_instance.get_node("AnimatedSprite2D") as AnimatedSprite2D
			
		if visuals_instance.has_node("AnimationPlayer"):
			_anim_player = visuals_instance.get_node("AnimationPlayer") as AnimationPlayer

	health = max_health

	# 5. Refresh UI layout systems
	health_changed.emit(health, max_health)
	exp_changed.emit(current_exp, exp_to_next_level, level)
	level_up_choices_changed.emit(pending_level_up_choices)
	stats_changed.emit(stat_damage, stat_speed, stat_intelligence, max_health)
	
	if not is_in_group("player"):
		add_to_group("player")

func _physics_process(_delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * get_movement_speed()

		if direction.x != 0:
			last_horizontal_direction = sign(direction.x)

		if _anim_player:
			if last_horizontal_direction < 0:
				_anim_player.play(anim_library + "/walk_left")
			else:
				_anim_player.play(anim_library + "/walk_right")
		
		if _weapon_sprite:
			_weapon_sprite.position.x = -8 if direction.x < 0 else 8
	else:
		velocity = Vector2.ZERO
		
		if _anim_player:
			if last_horizontal_direction < 0:
				_anim_player.play(anim_library + "/idle_left")
			else:
				_anim_player.play(anim_library + "/idle_right")

	move_and_slide()

# --- Equip Execution Core Hooks ---
func equip_weapon(weapon_resource: Resource) -> void:
	equipped_weapon = weapon_resource
	if _weapon_sprite and equipped_weapon and "texture" in equipped_weapon:
		_weapon_sprite.texture = equipped_weapon.texture
	elif _weapon_sprite:
		_weapon_sprite.texture = null
	stats_changed.emit(get_attack_damage(), stat_speed, stat_intelligence, max_health)

func unequip_weapon() -> void:
	equipped_weapon = null
	if _weapon_sprite:
		_weapon_sprite.texture = null
	stats_changed.emit(get_attack_damage(), stat_speed, stat_intelligence, max_health)

# --- Stat Calculations ---
func get_attack_damage() -> int:
	var total_damage = stat_damage
	if equipped_weapon and "damage_bonus" in equipped_weapon:
		total_damage += equipped_weapon.damage_bonus
	return total_damage

func get_movement_speed() -> float:
	var total_speed = base_speed + ((stat_speed - 10) * 5.0)
	if equipped_weapon and "speed_bonus" in equipped_weapon:
		total_speed += equipped_weapon.speed_bonus
	return total_speed

func take_damage(amount: int = 10):
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)

func heal(amount: int):
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

func add_experience(amount: int):
	if amount <= 0:
		return
	current_exp += amount
	while current_exp >= exp_to_next_level:
		current_exp -= exp_to_next_level
		level += 1
		pending_level_up_choices += 1
		level_changed.emit(level)
		exp_to_next_level = maxi(int(round(exp_to_next_level * 1.25)), 1)
	exp_changed.emit(current_exp, exp_to_next_level, level)
	level_up_choices_changed.emit(pending_level_up_choices)

func get_intelligence() -> int:
	return stat_intelligence

func apply_level_up_choice(choice_id: String):
	if pending_level_up_choices <= 0:
		return
	match choice_id:
		"ATK":
			stat_damage += 3
		"SPD":
			stat_speed += 2
		"INT":
			stat_intelligence += 2
		"VIT":
			max_health += 20
			health = mini(health + 20, max_health)
		_:
			return
	pending_level_up_choices -= 1
	health_changed.emit(health, max_health)
	stats_changed.emit(get_attack_damage(), stat_speed, stat_intelligence, max_health)
	level_up_choices_changed.emit(pending_level_up_choices)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				var mio_res = load("res://entities/character/Ookami Mio/Ookami Mio.tres")
				if mio_res:
					switch_character(mio_res)
			KEY_H:
				take_damage(10)
			KEY_J:
				heal(10)
			KEY_K:
				add_experience(25)
