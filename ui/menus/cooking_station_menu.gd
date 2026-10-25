# cooking_station_menu.gd
# Interactive Cooking & Talisman Crafting Pavilion Menu.
# Cook consumable spiritual dishes for combat buffs or inscribe sacred talismans for permanent account perks.

extends PanelContainer

@onready var close_btn: Button = $VBox/HeaderRow/CloseBtn
@onready var coin_label: Label = $VBox/HeaderRow/CoinLabel
@onready var recipe_list: VBoxContainer = $VBox/Scroll/RecipeList
@onready var buff_status_label: Label = $VBox/BuffStatusLabel

const RECIPES: Array[Dictionary] = [
	{
		"id": "bento",
		"type": "meal",
		"name": "🍱 Spiritual Bento",
		"desc": "Fully restores Party HP and grants +15% Movement Speed for 90 seconds.",
		"cost": 60,
		"speed_mult": 1.15,
		"attack_mult": 1.0,
		"cooldown_mult": 0.0,
		"duration": 90.0
	},
	{
		"id": "dumpling",
		"type": "meal",
		"name": "🥟 Oni War Dumpling",
		"desc": "Spicy Ayame-inspired dumpling granting +25% Attack Damage & +12% Crit Rate for 90 seconds.",
		"cost": 90,
		"speed_mult": 1.0,
		"attack_mult": 1.25,
		"cooldown_mult": 0.0,
		"duration": 90.0
	},
	{
		"id": "mochi",
		"type": "meal",
		"name": "🍡 Blizzard Snow Mochi",
		"desc": "Chilled Fubuki mochi reducing skill cooldowns by 25% for 90 seconds.",
		"cost": 80,
		"speed_mult": 1.0,
		"attack_mult": 1.0,
		"cooldown_mult": 0.25,
		"duration": 90.0
	},
	{
		"id": "ward_talisman",
		"type": "talisman",
		"name": "📿 Purification Ward Talisman",
		"desc": "Permanently increases Maximum HP by +20 for all party members.",
		"cost": 180,
		"hp_bonus": 20.0
	},
	{
		"id": "wind_talisman",
		"type": "talisman",
		"name": "🌪️ Swift Wind Talisman",
		"desc": "Permanently increases Base Movement Speed by +10 for all party members.",
		"cost": 180,
		"speed_bonus": 10.0
	},
	{
		"id": "fate_talisman",
		"type": "talisman",
		"name": "🎟️ Kami Fortune Charm",
		"desc": "Blessed shrine charm that rewards 1 Fate Ticket for Gacha summons.",
		"cost": 250,
		"gacha_tickets": 1
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(toggle_menu)

func _process(_delta: float) -> void:
	if visible and buff_status_label and GameManager:
		if not GameManager.active_meal_buff.is_empty():
			var meal_name: String = str(GameManager.active_meal_buff.get("name", "Meal"))
			var tr: float = float(GameManager.active_meal_buff.get("time_remaining", 0.0))
			buff_status_label.text = "Active Meal: %s (%.0fs remaining)" % [meal_name, tr]
		else:
			buff_status_label.text = "No active meal buff. Cook a dish before heading into battle!"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_O:
			toggle_menu()
			get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	visible = not visible
	if visible:
		_refresh_ui()

func open_menu() -> void:
	visible = true
	_refresh_ui()

func _refresh_ui() -> void:
	if not GameManager or not recipe_list:
		return

	if coin_label:
		coin_label.text = "⛩️ Shrine Coins: %d" % GameManager.shrine_coins

	for child in recipe_list.get_children():
		child.queue_free()

	for recipe in RECIPES:
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.14, 0.14, 0.18, 0.85)
		row_style.border_color = Color(0.4, 0.5, 0.6, 0.6)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(6)
		row_style.content_margin_left = 12
		row_style.content_margin_right = 12
		row_style.content_margin_top = 8
		row_style.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", row_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		row.add_child(hbox)

		var text_vbox := VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(text_vbox)

		var name_label := Label.new()
		name_label.text = recipe["name"]
		name_label.add_theme_font_size_override("font_size", 14)
		text_vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = recipe["desc"]
		desc_label.modulate = Color(0.8, 0.8, 0.85)
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_vbox.add_child(desc_label)

		var cost: int = recipe["cost"]
		var can_afford := GameManager.shrine_coins >= cost

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(140, 38)
		action_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var action_title := "🍲 Cook (%d C)" if recipe["type"] == "meal" else "📿 Craft (%d C)"
		action_btn.text = action_title % cost
		action_btn.disabled = not can_afford

		action_btn.pressed.connect(func():
			_execute_craft(recipe)
		)
		hbox.add_child(action_btn)

		recipe_list.add_child(row)

func _execute_craft(recipe: Dictionary) -> void:
	var cost: int = recipe["cost"]
	if GameManager.shrine_coins < cost:
		return

	GameManager.shrine_coins -= cost
	if EventBus:
		EventBus.currency_changed.emit(GameManager.shrine_coins)

	if recipe["type"] == "meal":
		GameManager.apply_meal_buff(
			recipe["name"],
			recipe["duration"],
			recipe["speed_mult"],
			recipe["attack_mult"],
			recipe["cooldown_mult"]
		)
		# Heal player upon eating meal
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_node("StatsComponent"):
			var stats: StatsComponent = player.get_node("StatsComponent")
			stats.heal(stats.max_hp)

		if AudioManager:
			AudioManager.play_sfx("purified")
	else:
		# Talisman
		if recipe.has("hp_bonus"):
			GameManager.add_talisman_hp(recipe["hp_bonus"])
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_node("StatsComponent"):
				var stats: StatsComponent = player.get_node("StatsComponent")
				stats.max_hp += recipe["hp_bonus"]
				stats.heal(recipe["hp_bonus"])
		if recipe.has("speed_bonus"):
			GameManager.add_talisman_speed(recipe["speed_bonus"])
		if recipe.has("gacha_tickets"):
			GameManager.shrine_coins += 100 # Fate refund bonus

		if AudioManager:
			AudioManager.play_sfx("coin")

	if SaveManager:
		SaveManager.save_game()

	_refresh_ui()
