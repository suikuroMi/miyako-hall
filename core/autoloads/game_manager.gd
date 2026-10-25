# game_manager.gd
# Global Autoload singleton managing game mode states (Story Mode vs Endless Mode),
# unlocked characters, story flags, wave progression, and difficulty scaling.

extends Node

# ---------------------------------------------------------------------------
# Enums & Signals
# ---------------------------------------------------------------------------
enum GameMode {
	STORY,
	ENDLESS,
	GYM_BOSS
}

signal party_swapped(slot_index: int, character_data: CharacterData)
signal party_composition_changed(active_party: Array[String])

# ---------------------------------------------------------------------------
# State Variables
# ---------------------------------------------------------------------------
var current_mode: GameMode = GameMode.STORY

# --- Story Progression & Party State ---
var unlocked_characters: Array[String] = ["ookami_mio", "shirakami_fubuki"]
var active_party: Array[String] = ["ookami_mio", "shirakami_fubuki"]
var active_party_index: int = 0
var active_character_id: String = "ookami_mio"
var party_health: Dictionary = {}
var _char_cache: Dictionary = {}

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
var character_awakenings: Dictionary = {
	"ookami_mio": 0,
	"shirakami_fubuki": 0,
	"nakiri_ayame": 0
}
var character_shards: Dictionary = {
	"ookami_mio": 20,
	"shirakami_fubuki": 0,
	"nakiri_ayame": 0
}
var gacha_pity: int = 0

# --- Shrine Base-Building & World Progression ---
var shrine_tier: int = 1
var rescued_spirits: Array[String] = []
var shrine_upgrades: Dictionary = {
	"torii": 1,
	"altar": 1,
	"garden": 0
}

# --- Permanent Faith Web / Talent Tree State ---
var talent_ranks: Dictionary = {
	"vitality": 0,
	"power": 0,
	"swiftness": 0,
	"spirit_fortune": 0,
	"divine_harvest": 0
}

# --- Chaos Artifacts & Run Modifiers ---
var active_chaos_modifiers: Array[String] = []

# --- Idle Expeditions & Museum Milestones ---
var idle_expeditions: Array[Dictionary] = []
var museum_milestones: Array[String] = []

# --- Cooking Meal Buffs & Talisman Artifacts ---
var active_meal_buff: Dictionary = {}
var talisman_hp_bonus: float = 0.0
var talisman_speed_bonus: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if EventBus:
		EventBus.boss_defeated.connect(_on_boss_defeated)
		EventBus.enemy_purified.connect(_on_enemy_purified)

func _process(delta: float) -> void:
	# Tick down meal buff if active
	if not active_meal_buff.is_empty():
		var tr: float = float(active_meal_buff.get("time_remaining", 0.0)) - delta
		if tr <= 0.0:
			active_meal_buff.clear()
		else:
			active_meal_buff["time_remaining"] = tr

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

# ---------------------------------------------------------------------------
# Party & Live Swapping API
# ---------------------------------------------------------------------------

## Retrieves CharacterData resource for a given character ID
func get_character_data(char_id: String) -> CharacterData:
	if _char_cache.has(char_id):
		return _char_cache[char_id]
	var path := "res://data/characters/%s.tres" % char_id
	if ResourceLoader.exists(path):
		var res: CharacterData = load(path) as CharacterData
		_char_cache[char_id] = res
		return res
	return null

## Live hot-swap to active party slot (0, 1, or 2)
func swap_to_party_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= active_party.size():
		return false
	if slot_idx == active_party_index and active_character_id == active_party[slot_idx]:
		return false

	var player: CharacterBody2D = get_tree().root.find_child("Player", true, false) as CharacterBody2D
	if not is_instance_valid(player):
		return false

	# Save current active character HP
	if player.has_node("StatsComponent"):
		var stats_comp: StatsComponent = player.get_node("StatsComponent")
		party_health[active_character_id] = stats_comp.current_hp

	# Swap to requested slot
	active_party_index = slot_idx
	active_character_id = active_party[slot_idx]
	var new_data: CharacterData = get_character_data(active_character_id)
	if not new_data:
		return false

	# Apply new character data to player entity
	if player.has_method("switch_character"):
		player.switch_character(new_data)

	# Restore individual HP for this character if saved
	if party_health.has(active_character_id) and player.has_node("StatsComponent"):
		var stats_comp: StatsComponent = player.get_node("StatsComponent")
		stats_comp.current_hp = clamp(party_health[active_character_id], 1.0, stats_comp.max_hp)
		if player.has_signal("health_changed"):
			player.health_changed.emit(stats_comp.current_hp, stats_comp.max_hp)
		if EventBus:
			EventBus.player_hp_changed.emit(stats_comp.current_hp, stats_comp.max_hp)

	party_swapped.emit(active_party_index, new_data)
	if EventBus:
		EventBus.active_character_swapped.emit(new_data)
	if SaveManager:
		SaveManager.save_game()
	return true

## Cycle to the next party member
func swap_to_next_party_member() -> void:
	if active_party.size() <= 1:
		return
	var next_slot := (active_party_index + 1) % active_party.size()
	swap_to_party_slot(next_slot)

## Assigns or swaps a character into an active party slot
func set_party_slot(slot_idx: int, char_id: String) -> void:
	if not unlocked_characters.has(char_id):
		return
	if slot_idx < 0 or slot_idx > 2:
		return

	var existing_idx := active_party.find(char_id)
	if existing_idx != -1 and existing_idx != slot_idx:
		var temp := active_party[slot_idx] if slot_idx < active_party.size() else ""
		active_party[slot_idx] = char_id
		if temp != "":
			active_party[existing_idx] = temp
		else:
			active_party.remove_at(existing_idx)
	else:
		if slot_idx < active_party.size():
			active_party[slot_idx] = char_id
		else:
			active_party.append(char_id)

	party_composition_changed.emit(active_party)
	if SaveManager:
		SaveManager.save_game()

func unlock_character(char_id: String) -> void:
	if not unlocked_characters.has(char_id):
		unlocked_characters.append(char_id)
		if active_party.size() < 3 and not active_party.has(char_id):
			active_party.append(char_id)
			party_composition_changed.emit(active_party)
		EventBus.character_unlocked.emit(char_id)
		if SaveManager:
			SaveManager.save_game()

func is_character_unlocked(char_id: String) -> bool:
	return unlocked_characters.has(char_id)

func set_story_flag(flag_name: String, value: Variant = true) -> void:
	story_flags[flag_name] = value
	if SaveManager:
		SaveManager.save_game()

func get_story_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag_name, default_value)

# ---------------------------------------------------------------------------
# Signal Listeners
# ---------------------------------------------------------------------------

func _on_boss_defeated(boss_id: String) -> void:
	if not purified_bosses.has(boss_id):
		purified_bosses.append(boss_id)
	set_story_flag("boss_defeated_" + boss_id, true)
	if SaveManager:
		SaveManager.save_game()

func _on_enemy_purified(_enemy_data: Resource, _pos: Vector2, _exp: int) -> void:
	register_enemy_kill()

# ---------------------------------------------------------------------------
# Gacha & Faith Resonance API
# ---------------------------------------------------------------------------

func add_coins(amount: int) -> void:
	shrine_coins += amount
	EventBus.currency_changed.emit(shrine_coins)
	if SaveManager:
		SaveManager.save_game()

func spend_coins(amount: int) -> bool:
	if shrine_coins >= amount:
		shrine_coins -= amount
		EventBus.currency_changed.emit(shrine_coins)
		if SaveManager:
			SaveManager.save_game()
		return true
	return false

func get_faith_rank(char_id: String) -> int:
	return faith_ranks.get(char_id, 0)

func upgrade_faith_rank(char_id: String) -> int:
	var current_rank: int = faith_ranks.get(char_id, 0)
	var new_rank: int = min(current_rank + 1, 6)
	faith_ranks[char_id] = new_rank
	EventBus.faith_resonance_upgraded.emit(char_id, new_rank)
	if SaveManager:
		SaveManager.save_game()
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

		# Guaranteed Pity trigger on 10th pull
		if gacha_pity >= 9:
			roll = 0.0

		if roll < banner.character_rate and banner.pool_characters.size() > 0:
			gacha_pity = 0
			var char_data: CharacterData = banner.pool_characters.pick_random() as CharacterData
			var char_id: String = char_data.id if char_data else "unknown"
			var char_name: String = char_data.name if char_data else "Holomember"

			if is_character_unlocked(char_id):
				# DUPLICATE -> Convert to Faith Resonance Token & 20 Awakening Shards!
				var new_rank: int = upgrade_faith_rank(char_id)
				add_character_shards(char_id, 20)
				pull_result = {
					"type": "character",
					"is_duplicate": true,
					"item": char_data,
					"name": char_name,
					"faith_rank": new_rank,
					"message": "Duplicate converted into 20 Awakening Shards & Faith Rank %d!" % new_rank
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
			gacha_pity += 1
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

# ---------------------------------------------------------------------------
# Spirit Rescue & Overworld Exploration
# ---------------------------------------------------------------------------

func is_spirit_rescued(soul_id: String) -> bool:
	return soul_id in rescued_spirits

func rescue_spirit(soul_id: String) -> void:
	if soul_id not in rescued_spirits:
		rescued_spirits.append(soul_id)
		if SaveManager:
			SaveManager.save_game()

# ---------------------------------------------------------------------------
# Shrine Base-Building & Buffs
# ---------------------------------------------------------------------------

func upgrade_shrine_tier() -> bool:
	var upgrade_costs: Array[int] = [0, 150, 300, 600]
	if shrine_tier >= 3:
		return false

	var next_tier: int = shrine_tier + 1
	var cost: int = upgrade_costs[shrine_tier]
	if shrine_coins < cost:
		return false

	shrine_coins -= cost
	shrine_tier = next_tier
	if EventBus:
		EventBus.currency_changed.emit(shrine_coins)
	if SaveManager:
		SaveManager.save_game()
	return true

func get_shrine_speed_bonus() -> float:
	# Tier 2+: +15% movement speed
	return 0.15 if shrine_tier >= 2 else 0.0

func get_shrine_exp_bonus() -> float:
	# Tier 3+: +20% bonus EXP
	return 0.20 if shrine_tier >= 3 else 0.0

func get_shrine_gacha_bonus() -> float:
	# Tier 3+: +10% 4/5-star rate
	return 0.10 if shrine_tier >= 3 else 0.0

# ---------------------------------------------------------------------------
# Character Awakening / Constellation Ranks
# ---------------------------------------------------------------------------

func add_character_shards(char_id: String, amount: int) -> void:
	character_shards[char_id] = character_shards.get(char_id, 0) + amount
	if SaveManager:
		SaveManager.save_game()

func awaken_character(char_id: String) -> bool:
	var current_stars: int = character_awakenings.get(char_id, 0)
	if current_stars >= 5:
		return false

	var shards: int = character_shards.get(char_id, 0)
	const COST_PER_STAR: int = 20
	if shards < COST_PER_STAR:
		return false

	character_shards[char_id] = shards - COST_PER_STAR
	character_awakenings[char_id] = current_stars + 1

	if AudioManager:
		AudioManager.play_sfx("level_up")
	if SaveManager:
		SaveManager.save_game()
	return true

func get_character_awakening_stars(char_id: String) -> int:
	return character_awakenings.get(char_id, 0)

# ---------------------------------------------------------------------------
# Faith Web / Permanent Talent Tree
# ---------------------------------------------------------------------------

func get_talent_cost(talent_id: String) -> int:
	var rank: int = talent_ranks.get(talent_id, 0)
	var base_costs: Dictionary = {
		"vitality": 80,
		"power": 100,
		"swiftness": 90,
		"spirit_fortune": 120,
		"divine_harvest": 150
	}
	return int(base_costs.get(talent_id, 100) * (rank + 1))

func upgrade_talent(talent_id: String) -> bool:
	var rank: int = talent_ranks.get(talent_id, 0)
	if rank >= 5:
		return false

	var cost: int = get_talent_cost(talent_id)
	if shrine_coins < cost:
		return false

	shrine_coins -= cost
	talent_ranks[talent_id] = rank + 1

	if EventBus:
		EventBus.currency_changed.emit(shrine_coins)
	if AudioManager:
		AudioManager.play_sfx("level_up")
	if SaveManager:
		SaveManager.save_game()
	return true

func get_talent_hp_bonus() -> float:
	return float(talent_ranks.get("vitality", 0) * 15.0)

func get_talent_attack_bonus() -> float:
	return float(talent_ranks.get("power", 0) * 3.0)

func get_talent_speed_bonus() -> float:
	return float(talent_ranks.get("swiftness", 0) * 0.05)

func get_talent_crit_bonus() -> float:
	return float(talent_ranks.get("spirit_fortune", 0) * 0.04)

func get_talent_harvest_bonus() -> float:
	return float(talent_ranks.get("divine_harvest", 0) * 0.10)

# ---------------------------------------------------------------------------
# Chaos Artifacts / Run Modifiers
# ---------------------------------------------------------------------------

func toggle_chaos_modifier(mod_id: String) -> void:
	if mod_id in active_chaos_modifiers:
		active_chaos_modifiers.erase(mod_id)
	else:
		active_chaos_modifiers.append(mod_id)

func is_chaos_modifier_active(mod_id: String) -> bool:
	return mod_id in active_chaos_modifiers

# ---------------------------------------------------------------------------
# Idle Expeditions
# ---------------------------------------------------------------------------

func dispatch_expedition(char_id: String, destination: String, duration_seconds: float) -> void:
	var exp_data: Dictionary = {
		"character_id": char_id,
		"destination": destination,
		"end_time": Time.get_unix_time_from_system() + duration_seconds,
		"duration": duration_seconds,
		"reward_coins": int(duration_seconds * 1.5),
		"reward_shards": 5
	}
	idle_expeditions.append(exp_data)
	if SaveManager:
		SaveManager.save_game()

func claim_expedition(index: int) -> Dictionary:
	if index < 0 or index >= idle_expeditions.size():
		return {}

	var exp_data: Dictionary = idle_expeditions[index]
	var now: float = Time.get_unix_time_from_system()
	if now < float(exp_data.get("end_time", 0.0)):
		return {}

	shrine_coins += int(exp_data.get("reward_coins", 50))
	var char_id: String = str(exp_data.get("character_id", "ookami_mio"))
	add_character_shards(char_id, int(exp_data.get("reward_shards", 5)))

	idle_expeditions.remove_at(index)
	if EventBus:
		EventBus.currency_changed.emit(shrine_coins)
	if AudioManager:
		AudioManager.play_sfx("coin")
	if SaveManager:
		SaveManager.save_game()
	return exp_data

# ---------------------------------------------------------------------------
# Cooking & Talisman Crafting Systems
# ---------------------------------------------------------------------------

func apply_meal_buff(meal_name: String, duration: float, speed_mult: float, attack_mult: float, cooldown_mult: float) -> void:
	active_meal_buff = {
		"name": meal_name,
		"time_remaining": duration,
		"speed_mult": speed_mult,
		"attack_mult": attack_mult,
		"cooldown_mult": cooldown_mult
	}
	if SaveManager:
		SaveManager.save_game()

func add_talisman_hp(amount: float) -> void:
	talisman_hp_bonus += amount
	if SaveManager:
		SaveManager.save_game()

func add_talisman_speed(amount: float) -> void:
	talisman_speed_bonus += amount
	if SaveManager:
		SaveManager.save_game()

