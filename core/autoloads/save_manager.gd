# save_manager.gd
# Global Autoload singleton managing game persistence to user://save_data.json.
# Saves and restores unlocked characters, active character, shrine coins,
# faith ranks, purified bosses, and story progression flags.

extends Node

const LEGACY_SAVE_PATH: String = "user://save_data.json"
var current_slot: int = 1

signal game_saved()
signal game_loaded()

var _is_saving: bool = false

func get_save_path(slot: int = current_slot) -> String:
	return "user://save_slot_%d.json" % slot

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Migrate legacy save if slot 1 does not exist yet
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(get_save_path(1)):
		var f_in = FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
		if f_in:
			var txt = f_in.get_as_text()
			f_in.close()
			var f_out = FileAccess.open(get_save_path(1), FileAccess.WRITE)
			if f_out:
				f_out.store_string(txt)
				f_out.close()

	# Delay load slightly to let other autoloads (like GameManager) initialize first
	call_deferred("load_game", current_slot)

## Saves all player progression data to disk in JSON format
func save_game(slot: int = current_slot) -> bool:
	if _is_saving:
		return false
	_is_saving = true

	var save_file_path := get_save_path(slot)
	var game_mgr = get_node_or_null("/root/GameManager")
	var save_dict := {
		"version": 1,
		"slot": slot,
		"timestamp": Time.get_datetime_string_from_system(),
		"unlocked_characters": game_mgr.unlocked_characters if game_mgr else ["ookami_mio", "shirakami_fubuki"],
		"active_party": game_mgr.active_party if game_mgr else ["ookami_mio", "shirakami_fubuki"],
		"active_party_index": game_mgr.active_party_index if game_mgr else 0,
		"active_character_id": game_mgr.active_character_id if game_mgr else "ookami_mio",
		"shrine_coins": game_mgr.shrine_coins if game_mgr else 600,
		"shrine_tier": game_mgr.shrine_tier if game_mgr else 1,
		"rescued_spirits": game_mgr.rescued_spirits if game_mgr else [],
		"character_awakenings": game_mgr.character_awakenings if game_mgr else {},
		"character_shards": game_mgr.character_shards if game_mgr else {},
		"talent_ranks": game_mgr.talent_ranks if game_mgr else {},
		"active_chaos_modifiers": game_mgr.active_chaos_modifiers if game_mgr else [],
		"idle_expeditions": game_mgr.idle_expeditions if game_mgr else [],
		"talisman_hp_bonus": game_mgr.talisman_hp_bonus if game_mgr else 0.0,
		"talisman_speed_bonus": game_mgr.talisman_speed_bonus if game_mgr else 0.0,
		"faith_ranks": game_mgr.faith_ranks if game_mgr else {"ookami_mio": 0},
		"purified_bosses": game_mgr.purified_bosses if game_mgr else [],
		"story_flags": game_mgr.story_flags if game_mgr else {}
	}

	var json_str := JSON.stringify(save_dict, "\t")
	var file := FileAccess.open(save_file_path, FileAccess.WRITE)
	if not file:
		push_warning("[SaveManager] Failed to open save file for writing: " + str(FileAccess.get_open_error()))
		_is_saving = false
		return false

	file.store_string(json_str)
	file.close()
	_is_saving = false
	game_saved.emit()
	return true

## Loads player progression from disk and applies it to GameManager
func load_game(slot: int = current_slot) -> bool:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[SaveManager] Failed to open save file for reading: " + str(FileAccess.get_open_error()))
		return false

	var json_str := file.get_as_text()
	file.close()

	var test_json_conv := JSON.new()
	var parse_err := test_json_conv.parse(json_str)
	if parse_err != OK:
		push_warning("[SaveManager] JSON Parse Error: " + test_json_conv.get_error_message())
		return false

	var data = test_json_conv.get_data()
	if not (data is Dictionary):
		return false

	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		if data.has("unlocked_characters") and data["unlocked_characters"] is Array:
			var chars: Array[String] = []
			for c in data["unlocked_characters"]:
				chars.append(str(c))
			game_mgr.unlocked_characters = chars

		if data.has("active_party") and data["active_party"] is Array:
			var party: Array[String] = []
			for p in data["active_party"]:
				party.append(str(p))
			game_mgr.active_party = party

		if data.has("active_party_index"):
			game_mgr.active_party_index = int(data["active_party_index"])

		if data.has("active_character_id"):
			game_mgr.active_character_id = str(data["active_character_id"])

		if data.has("shrine_coins"):
			game_mgr.shrine_coins = int(data["shrine_coins"])

		if data.has("shrine_tier"):
			game_mgr.shrine_tier = int(data["shrine_tier"])

		if data.has("rescued_spirits") and data["rescued_spirits"] is Array:
			var spirits: Array[String] = []
			for s in data["rescued_spirits"]:
				spirits.append(str(s))
			game_mgr.rescued_spirits = spirits

		if data.has("character_awakenings") and data["character_awakenings"] is Dictionary:
			var awk: Dictionary = {}
			for k in data["character_awakenings"].keys():
				awk[str(k)] = int(data["character_awakenings"][k])
			game_mgr.character_awakenings = awk

		if data.has("character_shards") and data["character_shards"] is Dictionary:
			var shards: Dictionary = {}
			for k in data["character_shards"].keys():
				shards[str(k)] = int(data["character_shards"][k])
			game_mgr.character_shards = shards

		if data.has("talent_ranks") and data["talent_ranks"] is Dictionary:
			var talents: Dictionary = {}
			for k in data["talent_ranks"].keys():
				talents[str(k)] = int(data["talent_ranks"][k])
			game_mgr.talent_ranks = talents

		if data.has("active_chaos_modifiers") and data["active_chaos_modifiers"] is Array:
			var mods: Array[String] = []
			for m in data["active_chaos_modifiers"]:
				mods.append(str(m))
			game_mgr.active_chaos_modifiers = mods

		if data.has("idle_expeditions") and data["idle_expeditions"] is Array:
			var exps: Array[Dictionary] = []
			for e in data["idle_expeditions"]:
				if e is Dictionary:
					exps.append(e)
			game_mgr.idle_expeditions = exps

		if data.has("talisman_hp_bonus"):
			game_mgr.talisman_hp_bonus = float(data["talisman_hp_bonus"])

		if data.has("talisman_speed_bonus"):
			game_mgr.talisman_speed_bonus = float(data["talisman_speed_bonus"])

		if data.has("faith_ranks") and data["faith_ranks"] is Dictionary:
			var ranks: Dictionary = {}
			for k in data["faith_ranks"].keys():
				ranks[str(k)] = int(data["faith_ranks"][k])
			game_mgr.faith_ranks = ranks

		if data.has("purified_bosses") and data["purified_bosses"] is Array:
			var bosses: Array[String] = []
			for b in data["purified_bosses"]:
				bosses.append(str(b))
			game_mgr.purified_bosses = bosses

		if data.has("story_flags") and data["story_flags"] is Dictionary:
			game_mgr.story_flags = data["story_flags"]

	game_loaded.emit()
	return true

## Deletes the save file (reset progress)
func delete_save(slot: int = current_slot) -> void:
	var path: String = get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
