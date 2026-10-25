# holo_archive.gd
# In-game Encyclopedia logging Holomembers, Stigmata Bestiary, and World Lore.
# Accessible via [L] hotkey or Top Bar button.

extends PanelContainer

@onready var content_label: Label = $VBox/ContentScroll/ContentLabel
@onready var tab_holomembers: Button = $VBox/TabRow/HolomembersBtn
@onready var tab_bestiary: Button = $VBox/TabRow/BestiaryBtn
@onready var tab_mythos: Button = $VBox/TabRow/MythosBtn
@onready var close_btn: Button = $VBox/HeaderRow/CloseBtn

var _active_tab: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(toggle_archive)
	if tab_holomembers:
		tab_holomembers.pressed.connect(_show_tab.bind(0))
	if tab_bestiary:
		tab_bestiary.pressed.connect(_show_tab.bind(1))
	if tab_mythos:
		tab_mythos.pressed.connect(_show_tab.bind(2))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_L:
			toggle_archive()
			get_viewport().set_input_as_handled()

func toggle_archive() -> void:
	visible = not visible
	if visible:
		_show_tab(_active_tab)

func _show_tab(index: int) -> void:
	_active_tab = index
	match index:
		0:
			_display_holomembers()
		1:
			_display_bestiary()
		2:
			_display_mythos()

func _display_holomembers() -> void:
	var text := ""
	text += "⛩️ OOKAMI MIO — The Diviner Shrine Maiden\n"
	text += "Archetype: Diviner / Spellcaster | Favored: Tarot Talisman\n"
	text += "Lore: A warm and nurturing shrine maiden of Kamikitakuni. Channels spiritual tarots and sacred pulses to cleanse stigmata corruption from the land.\n\n"

	text += "❄️ SHIRAKAMI FUBUKI — The White Fox of the Blizzard\n"
	text += "Archetype: Swift Assassin / Frost Weaver | Favored: Spirit Blade\n"
	text += "Lore: Guardian kami of the Blizzard Peaks. Agile and playful, her ice darts pierce through corrupted hordes with biting wind.\n\n"

	text += "🔥 NAKIRI AYAME — The Asura Demon Swordswoman\n"
	text += "Archetype: Melee Duelist / Berserker | Favored: Dual Blades / Scythe\n"
	text += "Lore: An Oni warrior dwelling within the Haunted Dojo. Master of flame-infused blade arts who unleashes demonic speed when challenged in battle."
	content_label.text = text

func _display_bestiary() -> void:
	var text := ""
	text += "🟢 CORRUPTED SLIME\n"
	text += "Type: Common Stigmata Residue | Danger: ★☆☆☆☆\n"
	text += "Description: Globules of wandering spirit matter tainted by the False Moon. They multiply in overgrown routes and charge toward pure spirits.\n\n"

	text += "👤 BASIC CHASER APPARITION\n"
	text += "Type: Hostile Shadow Entity | Danger: ★★☆☆☆\n"
	text += "Description: Restless shadows that patrol corridors. Upon spotting an intruder, they sound an alert (!) and pursue aggressively.\n\n"

	text += "🔥 GYM LEADER: CORRUPTED NAKIRI AYAME\n"
	text += "Type: Possessed Holomember Boss | Danger: ★★★★☆\n"
	text += "Description: Consumed by purgatory flames within the Dojo. Sweeps the battlefield with whirling blade dances and enters an enraged state below 50% HP.\n\n"

	text += "❄️ GYM LEADER: CORRUPTED SHIRAKAMI FUBUKI\n"
	text += "Type: Possessed Holomember Boss | Danger: ★★★★★\n"
	text += "Description: Encased in absolute permafrost upon the mountain summit. Blasts spiraling blizzard projectiles and teleports via Frost Nova."
	content_label.text = text

func _display_mythos() -> void:
	var text := ""
	text += "🌑 THE FALSE MOON & ECLIPSE TWILIGHT\n"
	text += "An oppressive celestial anomaly has gripped the nexus sky, bathing the realm in false twilight. Under its crimson eclipse, corrupted monsters gain swiftness and ferocity, yet yield double faith essence when purified.\n\n"

	text += "⛩️ KAMIKITAKUNI SHRINE\n"
	text += "The ancient sanctuary of spiritual balance. Rebuilding its sacred Torii gates and cultivating its spirit gardens grants worldwide blessings to all traveling Holomembers.\n\n"

	text += "✨ THE HIGHER OBSERVERS\n"
	text += "Cosmic presences existing beyond the veil of time. They observe the trials of the Holo nexus, granting card blessings and soul awakenings to worthy maidens."
	content_label.text = text
