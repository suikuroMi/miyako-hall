# expedition_board.gd
# Dispatch inactive Holomembers on timed resource-gathering expeditions across alternate dimensions.
# Toggled via [U] hotkey or Shrine Dispatch station.

extends PanelContainer

@onready var close_btn: Button = $VBox/HeaderRow/CloseBtn
@onready var mission_list: VBoxContainer = $VBox/Scroll/MissionList

const MISSIONS: Array[Dictionary] = [
	{
		"name": "🌌 Underworld Spirit Expanse",
		"desc": "Scout the mist-covered boundary for lost tarots and faith residue.",
		"duration": 45.0,
		"char_id": "ookami_mio",
		"coins": 100,
		"shards": 5
	},
	{
		"name": "🏙️ Cyber Akiba Neon Wastes",
		"desc": "Infiltrate rogue cyber-stigmata nodes to gather swift tech fragments.",
		"duration": 90.0,
		"char_id": "shirakami_fubuki",
		"coins": 180,
		"shards": 5
	},
	{
		"name": "🔥 Netherrealm Flame Dojo",
		"desc": "Duel lingering Oni phantoms to acquire purgatory blade shards.",
		"duration": 150.0,
		"char_id": "nakiri_ayame",
		"coins": 280,
		"shards": 5
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(toggle_board)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_U:
			toggle_board()
			get_viewport().set_input_as_handled()

func toggle_board() -> void:
	visible = not visible
	if visible:
		_refresh_missions()
		get_tree().paused = true
	else:
		get_tree().paused = false

func _refresh_missions() -> void:
	if not GameManager:
		return

	for child in mission_list.get_children():
		child.queue_free()

	var now: float = Time.get_unix_time_from_system()

	for i in range(MISSIONS.size()):
		var m: Dictionary = MISSIONS[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		mission_list.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var title := Label.new()
		title.text = m.name
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		info.add_child(title)

		var desc := Label.new()
		desc.text = "%s (Reward: %d 💰 + %d Shards)" % [m.desc, m.coins, m.shards]
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		info.add_child(desc)

		# Check if currently active in GameManager.idle_expeditions
		var active_idx := -1
		for j in range(GameManager.idle_expeditions.size()):
			if GameManager.idle_expeditions[j].get("destination") == m.name:
				active_idx = j
				break

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 36)

		if active_idx >= 0:
			var exp_data: Dictionary = GameManager.idle_expeditions[active_idx]
			var end_time: float = float(exp_data.get("end_time", 0.0))
			if now >= end_time:
				btn.text = "🎁 Claim Reward"
				btn.pressed.connect(func():
					GameManager.claim_expedition(active_idx)
					_refresh_missions()
				)
			else:
				var remaining: int = int(end_time - now)
				btn.text = "⏳ In Progress (%ds)" % remaining
				btn.disabled = true
		else:
			btn.text = "🚀 Dispatch (%ds)" % int(m.duration)
			btn.pressed.connect(func():
				GameManager.dispatch_expedition(m.char_id, m.name, m.duration)
				_refresh_missions()
			)

		row.add_child(btn)
