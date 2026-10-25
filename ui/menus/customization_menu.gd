# customization_menu.gd
# Roster swap, outfit palettes, and Faith Resonance (Constellation) display.

extends PanelContainer

# Nodes
@onready var _roster_list: VBoxContainer = $Content/Columns/Left/RosterScroll/RosterList
@onready var _name_label: Label = $Content/Columns/Right/Profile/NameLabel
@onready var _archetype_label: Label = $Content/Columns/Right/Profile/ArchetypeLabel
@onready var _stats_label: Label = $Content/Columns/Right/Profile/StatsLabel
@onready var _faith_rank_label: Label = $Content/Columns/Right/FaithSection/FaithRankLabel
@onready var _faith_perks_label: Label = $Content/Columns/Right/FaithSection/FaithPerksLabel
@onready var _select_char_btn: Button = $Content/Columns/Right/Actions/SelectCharButton
@onready var _close_btn: Button = $Content/Columns/Right/Actions/CloseButton

# Palettes
@onready var _palette_options: OptionButton = $Content/Columns/Right/Customization/PaletteOptions

var _selected_character_id: String = "ookami_mio"
var _character_cache: Dictionary = {}

const ARCHETYPE_NAMES: Array[String] = [
	"Shrine Maiden (Purification & AoE)",
	"Vanguard (High HP / Defense)",
	"Assassin (High Speed / Crit)",
	"Reaper (Attack / Life Steal)",
	"Marksman (Ranged Projectiles)"
]

const FAITH_PERKS: Array[String] = [
	"⭐ Rank 0: Base Resonance",
	"⭐ Rank 1: +10% Active Skill Damage",
	"⭐ Rank 2: -15% Skill Cooldown",
	"⭐ Rank 3: +15 Attack Power & Crit Rate +5%",
	"⭐ Rank 4: Fleet-Footed: +20% Movement Speed",
	"⭐ Rank 5: Sacred Soul: +25% Max HP & Armor +5",
	"⭐ Rank 6: Awakened Kami: Ultimate Burst Empowered"
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_preload_characters()
	_setup_palettes()

	_select_char_btn.pressed.connect(_on_select_char_pressed)
	_close_btn.pressed.connect(toggle_menu)
	_palette_options.item_selected.connect(_on_palette_selected)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			toggle_menu()
			get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	visible = not visible
	if visible:
		_refresh_roster()
		_select_character(_selected_character_id)
		get_tree().paused = true
	else:
		get_tree().paused = false

func _preload_characters() -> void:
	var paths := {
		"ookami_mio": "res://data/characters/ookami_mio.tres",
		"shirakami_fubuki": "res://data/characters/shirakami_fubuki.tres",
		"nakiri_ayame": "res://data/characters/nakiri_ayame.tres"
	}
	for id in paths.keys():
		if ResourceLoader.exists(paths[id]):
			_character_cache[id] = load(paths[id])

func _setup_palettes() -> void:
	_palette_options.clear()
	_palette_options.add_item("Default Palette", 0)
	_palette_options.add_item("Shrine Crimson", 1)
	_palette_options.add_item("Spirit Azure", 2)
	_palette_options.add_item("Midnight Shadow", 3)
	_palette_options.add_item("Solar Gold", 4)

func _refresh_roster() -> void:
	for child in _roster_list.get_children():
		child.queue_free()

	var unlocked: Array = GameManager.unlocked_characters if GameManager else ["ookami_mio"]
	for char_id in unlocked:
		var btn := Button.new()
		var char_data: CharacterData = _character_cache.get(char_id, null)
		var display_title: String = char_data.name if (char_data and char_data.name != "") else char_id.capitalize()
		var rank: int = GameManager.get_faith_rank(char_id) if GameManager else 0

		btn.text = "%s (⭐ R%d)" % [display_title, rank]
		btn.custom_minimum_size = Vector2(180, 44)
		btn.pressed.connect(_select_character.bind(char_id))
		_roster_list.add_child(btn)

func _select_character(char_id: String) -> void:
	_selected_character_id = char_id
	var char_data: CharacterData = _character_cache.get(char_id, null)
	if not char_data:
		return

	_name_label.text = char_data.name if char_data.name != "" else char_id.capitalize()
	var arch_idx: int = clamp(int(char_data.archetype), 0, ARCHETYPE_NAMES.size() - 1)
	_archetype_label.text = "Archetype: " + ARCHETYPE_NAMES[arch_idx]
	_stats_label.text = "❤️ HP: %d   ⚔️ ATK: %d   ⚡ SPD: %d   🧠 INT: %d" % [
		int(char_data.base_health), int(char_data.base_power), int(char_data.base_speed), int(char_data.base_intelligence)
	]

	# Faith Resonance (Constellation) Display
	var rank: int = GameManager.get_faith_rank(char_id) if GameManager else 0
	var stars: int = GameManager.get_character_awakening_stars(char_id) if GameManager else 0
	var shards: int = GameManager.character_shards.get(char_id, 0) if GameManager else 0
	var star_str := ""
	for s in range(5):
		star_str += "★" if s < stars else "☆"

	_faith_rank_label.text = "✨ Faith Resonance: Rank %d   |   Awakening: %s (%d/20 Shards)" % [rank, star_str, shards]
	
	var perks_text: String = ""
	for i in range(rank + 1):
		perks_text += FAITH_PERKS[i] + "\n"
	if stars > 0:
		perks_text += "🌟 Awakening Passive: +%d%% Base Stats & Trait Amplification\n" % (stars * 5)
	_faith_perks_label.text = perks_text

func _on_select_char_pressed() -> void:
	if not GameManager:
		return
	# Assign to active party slot and deploy
	GameManager.set_party_slot(GameManager.active_party_index, _selected_character_id)
	GameManager.swap_to_party_slot(GameManager.active_party_index)
	toggle_menu()

func _on_palette_selected(index: int) -> void:
	var presets := ["default", "shrine_crimson", "spirit_azure", "midnight_shadow", "solar_gold"]
	if index >= 0 and index < presets.size():
		var player = get_tree().root.find_child("Player", true, false)
		if is_instance_valid(player):
			var custom_comp = player.get_node_or_null("CustomizationComponent")
			if custom_comp and custom_comp.has_method("apply_palette_preset"):
				custom_comp.apply_palette_preset(presets[index])
