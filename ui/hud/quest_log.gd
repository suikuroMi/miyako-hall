# quest_log.gd
# Interactive Quest Log & Faith Tracker panel.
# Displays story progression, rescued spirits count, shrine tiers, and regional corruption.
# Toggled via [J] hotkey or Top Bar button.

extends PanelContainer

@onready var objective_label: Label = $VBox/ObjectiveSection/ObjectivesList
@onready var faith_label: Label = $VBox/FaithSection/FaithList
@onready var corruption_label: Label = $VBox/CorruptionSection/CorruptionList
@onready var close_btn: Button = $VBox/HeaderRow/CloseBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(toggle_log)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_J:
			toggle_log()
			get_viewport().set_input_as_handled()

func toggle_log() -> void:
	visible = not visible
	if visible:
		_refresh_quest_data()

func _refresh_quest_data() -> void:
	if not GameManager:
		return

	# 1. Main Objectives
	var ayame_cleared: bool = GameManager.get_story_flag("gym_cleared_nakiri_ayame")
	var fubuki_cleared: bool = GameManager.get_story_flag("gym_cleared_shirakami_fubuki")

	var obj_text := ""
	obj_text += "• [x] Reawaken at Kamikitakuni Shrine\n"
	obj_text += "• [%s] Defeat & Purify Nakiri Ayame (Haunted Dojo)\n" % ("x" if ayame_cleared else " ")
	obj_text += "• [%s] Defeat & Purify Shirakami Fubuki (Blizzard Peaks)\n" % ("x" if fubuki_cleared else " ")
	if ayame_cleared and fubuki_cleared:
		obj_text += "✨ [COMPLETE] All regional Gym Leaders purified! False Moon retreating!"
	else:
		obj_text += "⚔️ [ACTIVE] Challenge remaining Gym Leaders to unite your Holo party!"
	objective_label.text = obj_text

	# 2. Faith & Spirit Rescue Tracker
	var rescued_count: int = GameManager.rescued_spirits.size()
	var tier: int = GameManager.shrine_tier
	var faith_text := ""
	faith_text += "✨ Wandering Spirits Rescued: %d\n" % rescued_count
	faith_text += "⛩️ Shrine Hub Level: Tier %d / 3\n" % tier
	faith_text += "💰 Shrine Faith Coins: %d\n" % GameManager.shrine_coins
	faith_text += "🌟 Active Blessings: "
	if tier == 1:
		faith_text += "HP/Mana Sanctuary"
	elif tier == 2:
		faith_text += "HP/Mana Sanctuary, +15% Party Swiftness"
	elif tier >= 3:
		faith_text += "HP/Mana Sanctuary, +15% Swiftness, +20% EXP, +10% Gacha Luck"
	faith_label.text = faith_text

	# 3. Regional Corruption
	var corr_text := ""
	corr_text += "• Kamikitakuni Shrine: 0% [Purified Sanctuary]\n"
	corr_text += "• Route 1 Forest: %s\n" % ("10% [Clear]" if rescued_count >= 2 else "35% [Slime Infested]")
	corr_text += "• Haunted Dojo: %s\n" % ("0% [Purified]" if ayame_cleared else "80% [Corrupted Oni Ward]")
	corr_text += "• Blizzard Peaks: %s\n" % ("0% [Purified]" if fubuki_cleared else "90% [Permafrost Storm]")
	corruption_label.text = corr_text
