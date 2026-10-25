# game_manager.gd
# Global Autoload singleton managing game mode states (Story Mode vs Endless Mode),
# unlocked characters, story flags, wave progression, and difficulty scaling.

extends Node

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------
enum GameMode {
	STORY,
	ENDLESS,
	GYM_BOSS
}

# ---------------------------------------------------------------------------
# State Variables
# ---------------------------------------------------------------------------
var current_mode: GameMode = GameMode.STORY

# --- Story Progression State ---
var unlocked_characters: Array[String] = ["ookami_mio"]
var active_character_id: String = "ookami_mio"
var purified_bosses: Array[String] = []
var story_flags: Dictionary = {
	"tutorial_completed": false,
	"shrine_visited": true,
	"route_01_discovered": false
}

# --- Endless Mode State ---
var current_wave: int = 1
var wave_duration: float = 45.0 # Seconds per wave
var wave_timer: float = 0.0
var total_kills: int = 0
var survival_time: float = 0.0
var difficulty_multiplier: float = 1.0
var is_game_active: bool = false

# --- Gacha & Faith Resonance (Constellations) State ---
var shrine_coins: int = 600
var faith_ranks: Dictionary = {
	"ookami_mio": 0
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if EventBus:
		EventBus.boss_defeated.connect(_on_boss_defeated)
		EventBus.enemy_purified.connect(_on_enemy_purified)

func _process(delta: float) -> void:
	if current_mode == GameMode.ENDLESS and is_game_active:
		survival_time += delta
		wave_timer += delta
		
		# Broadcast periodic stats for HUD
		EventBus.endless_stats_updated.emit(survival_time, current_wave, total_kills)
		
		# Wave advancement
		if wave_timer >= wave_duration:
			wave_timer = 0.0
			EventBus.wave_completed.emit(current_wave)
			current_wave += 1
			difficulty_multiplier += 0.25
			EventBus.wave_started.emit(current_wave)

# ---------------------------------------------------------------------------
# Game Mode Control
# ---------------------------------------------------------------------------

## Starts or warps to Story Mode starting hub
func start_story_mode() -> void:
	current_mode = GameMode.STORY
	is_game_active = true
	EventBus.game_mode_changed.emit(current_mode)
	
	if SceneManager:
		SceneManager.transition_to_map("res://modes_and_maps/story_mode/kamikitakuni_shrine.tscn", "default")
	else:
		get_tree().change_scene_to_file("res://modes_and_maps/story_mode/kamikitakuni_shrine.tscn")

## Starts or resets Endless Mode arena
func start_endless_mode() -> void:
	current_mode = GameMode.ENDLESS
	reset_endless_stats()
	is_game_active = true
	EventBus.game_mode_changed.emit(current_mode)
	EventBus.wave_started.emit(current_wave)
	
	if SceneManager:
		SceneManager.transition_to_map("res://modes_and_maps/endless_mode/endless_arena.tscn", "default")
	else:
		get_tree().change_scene_to_file("res://modes_and_maps/endless_mode/endless_arena.tscn")

func reset_endless_stats() -> void:
	current_wave = 1
	wave_timer = 0.0
	total_kills = 0
	survival_time = 0.0
	difficulty_multiplier = 1.0

func register_enemy_kill() -> void:
	total_kills += 1
	if current_mode == GameMode.ENDLESS:
		EventBus.endless_stats_updated.emit(survival_time, current_wave, total_kills)

func trigger_game_over() -> void:
	is_game_active = false
	var stats := {
		"mode": current_mode,
		"survival_time": survival_time,
		"waves_cleared": current_wave,
		"total_kills": total_kills
	}
	EventBus.game_over.emit(stats)

# ---------------------------------------------------------------------------
# Story & Progression API
# ---------------------------------------------------------------------------

func unlock_character(char_id: String) -> void:
	if not unlocked_characters.has(char_id):
		unlocked_characters.append(char_id)
		EventBus.character_unlocked.emit(char_id)

func is_character_unlocked(char_id: String) -> bool:
	return unlocked_characters.has(char_id)

func set_story_flag(flag_name: String, value: Variant = true) -> void:
	story_flags[flag_name] = value

func get_story_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag_name, default_value)

# ---------------------------------------------------------------------------
# Signal Listeners
# ---------------------------------------------------------------------------

func _on_boss_defeated(boss_id: String) -> void:
	if not purified_bosses.has(boss_id):
		purified_bosses.append(boss_id)
	set_story_flag("boss_defeated_" + boss_id, true)

func _on_enemy_purified(_enemy_data: Resource, _pos: Vector2, _exp: int) -> void:
	register_enemy_kill()

# ---------------------------------------------------------------------------
# Gacha & Faith Resonance API
# ---------------------------------------------------------------------------

func add_coins(amount: int) -> void:
	shrine_coins += amount
	EventBus.currency_changed.emit(shrine_coins)

func spend_coins(amount: int) -> bool:
	if shrine_coins >= amount:
		shrine_coins -= amount
		EventBus.currency_changed.emit(shrine_coins)
		return true
	return false

func get_faith_rank(char_id: String) -> int:
	return faith_ranks.get(char_id, 0)

func upgrade_faith_rank(char_id: String) -> int:
	var current_rank: int = faith_ranks.get(char_id, 0)
	var new_rank: int = min(current_rank + 1, 6)
	faith_ranks[char_id] = new_rank
	EventBus.faith_resonance_upgraded.emit(char_id, new_rank)
	return new_rank

## Performs single or multi-pulls on a GachaBannerData
func pull_gacha(banner: GachaBannerData, count: int = 1) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var total_cost: int = banner.cost_per_pull * count

	if not spend_coins(total_cost):
		push_warning("[GameManager] Not enough shrine coins to pull!")
		return results

	for i in range(count):
		var roll: float = randf()
		var pull_result: Dictionary = {}

		if roll < banner.character_rate and banner.pool_characters.size() > 0:
			var char_data: CharacterData = banner.pool_characters.pick_random() as CharacterData
			var char_id: String = char_data.id if char_data else "unknown"
			var char_name: String = char_data.name if char_data else "Holomember"

			if is_character_unlocked(char_id):
				# DUPLICATE -> Convert to Faith Resonance Token!
				var new_rank: int = upgrade_faith_rank(char_id)
				pull_result = {
					"type": "character",
					"is_duplicate": true,
					"item": char_data,
					"name": char_name,
					"faith_rank": new_rank,
					"message": "Duplicate converted into Faith Resonance Rank %d!" % new_rank
				}
			else:
				# NEW CHARACTER UNLOCKED!
				unlock_character(char_id)
				faith_ranks[char_id] = 0
				pull_result = {
					"type": "character",
					"is_duplicate": false,
					"item": char_data,
					"name": char_name,
					"faith_rank": 0,
					"message": "New Holomember Unlocked!"
				}
		else:
			var weapon_data: WeaponData = banner.pool_weapons.pick_random() as WeaponData
			var w_name: String = weapon_data.display_name if weapon_data else "Sacred Weapon"
			pull_result = {
				"type": "weapon",
				"is_duplicate": false,
				"item": weapon_data,
				"name": w_name,
				"message": "Acquired Weapon: " + w_name
			}

		results.append(pull_result)

	EventBus.gacha_pull_completed.emit(results)
	return results
