# talent_tree.gd
# Interactive Faith Web / Permanent Talent Tree.
# Spends Shrine Coins to permanently bolster base stats globally across all Holomembers.

extends PanelContainer

@onready var close_btn: Button = $VBox/HeaderRow/CloseBtn
@onready var coin_label: Label = $VBox/HeaderRow/CoinLabel
@onready var node_list: VBoxContainer = $VBox/Scroll/NodeList

const TALENT_DEFS: Array[Dictionary] = [
	{
		"id": "vitality",
		"name": "❤️ Sacred Vitality",
		"desc": "+15 Maximum HP per rank",
		"icon": "❤️"
	},
	{
		"id": "power",
		"name": "⚔️ Spiritual Force",
		"desc": "+3 Base Attack Power per rank",
		"icon": "⚔️"
	},
	{
		"id": "swiftness",
		"name": "⚡ Kami Swiftness",
		"desc": "+5% Movement Speed per rank",
		"icon": "⚡"
	},
	{
		"id": "spirit_fortune",
		"name": "🔮 Tarot Divination",
		"desc": "+4% Critical Hit Rate per rank",
		"icon": "🔮"
	},
	{
		"id": "divine_harvest",
		"name": "🌾 Divine Bounty",
		"desc": "+10% EXP & Shrine Coin gains per rank",
		"icon": "🌾"
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(toggle_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_K:
			toggle_menu()
			get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	visible = not visible
	if visible:
		_refresh_talents()
		get_tree().paused = true
	else:
		get_tree().paused = false

func _refresh_talents() -> void:
	if not GameManager:
		return

	if coin_label:
		coin_label.text = "💰 Shrine Coins: %d" % GameManager.shrine_coins

	for child in node_list.get_children():
		child.queue_free()

	for t in TALENT_DEFS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		node_list.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var title := Label.new()
		var rank: int = GameManager.talent_ranks.get(t.id, 0)
		title.text = "%s [Rank %d/5]" % [t.name, rank]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		info.add_child(title)

		var desc := Label.new()
		desc.text = t.desc
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		info.add_child(desc)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 36)
		if rank >= 5:
			btn.text = "MAX RANK"
			btn.disabled = true
		else:
			var cost: int = GameManager.get_talent_cost(t.id)
			btn.text = "Upgrade (%d 💰)" % cost
			btn.disabled = GameManager.shrine_coins < cost
			btn.pressed.connect(func():
				if GameManager.upgrade_talent(t.id):
					_refresh_talents()
			)
		row.add_child(btn)
