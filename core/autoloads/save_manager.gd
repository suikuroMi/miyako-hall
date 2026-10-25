# save_manager.gd
# Global Autoload singleton managing game persistence to user://save_data.json.
# Saves and restores unlocked characters, active character, shrine coins,
# faith ranks, purified bosses, and story progression flags.

extends Node

const SAVE_PATH: String = "user://save_data.json"

signal game_saved()
signal game_loaded()

var _is_saving: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Delay load slightly to let other autoloads (like GameManager) initialize first
	call_deferred("load_game")

## Saves all player progression data to disk in JSON format
func save_game() -> bool:
	if _is_saving:
		return false
	_is_saving = true

	var game_mgr = get_node_or_null("/root/GameManager")
	var save_dict := {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"unlocked_characters": game_mgr.unlocked_characters if game_mgr else ["ookami_mio"],
		"active_character_id": game_mgr.active_character_id if game_mgr else "ookami_mio",
		"shrine_coins": game_mgr.shrine_coins if game_mgr else 600,
		"faith_ranks": game_mgr.faith_ranks if game_mgr else {"ookami_mio": 0},
		"purified_bosses": game_mgr.purified_bosses if game_mgr else [],
		"story_flags": game_mgr.story_flags if game_mgr else {}
	}

	var json_str := JSON.stringify(save_dict, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
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
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
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

		if data.has("active_character_id"):
			game_mgr.active_character_id = str(data["active_character_id"])

		if data.has("shrine_coins"):
			game_mgr.shrine_coins = int(data["shrine_coins"])

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
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
