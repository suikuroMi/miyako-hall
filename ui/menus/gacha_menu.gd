# gacha_menu.gd
# Interactive Gacha summoning screen with single and 10x pulls,
# currency display, and duplicate "Faith Resonance" showcase.

extends PanelContainer

@export var default_banner: GachaBannerData

# Nodes
@onready var _banner_title: Label = $Content/Header/BannerTitle
@onready var _banner_desc: Label = $Content/Header/BannerDesc
@onready var _coins_label: Label = $Content/Header/CoinsLabel
@onready var _single_pull_btn: Button = $Content/Actions/SinglePullButton
@onready var _multi_pull_btn: Button = $Content/Actions/MultiPullButton
@onready var _close_btn: Button = $Content/Actions/CloseButton

# Results Modal
@onready var _results_overlay: PanelContainer = $ResultsOverlay
@onready var _results_container: VBoxContainer = $ResultsOverlay/ResultsVBox/Scroll/ResultsList
@onready var _claim_btn: Button = $ResultsOverlay/ResultsVBox/ClaimButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_results_overlay.visible = false

	if not default_banner and ResourceLoader.exists("res://data/gacha_pools/standard_banner.tres"):
		default_banner = load("res://data/gacha_pools/standard_banner.tres")

	_single_pull_btn.pressed.connect(_on_single_pull_pressed)
	_multi_pull_btn.pressed.connect(_on_multi_pull_pressed)
	_close_btn.pressed.connect(toggle_menu)
	_claim_btn.pressed.connect(func(): _results_overlay.visible = false)

	if EventBus:
		EventBus.currency_changed.connect(_on_currency_changed)

	_refresh_banner_info()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			toggle_menu()
			get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	visible = not visible
	if visible:
		_refresh_banner_info()
		get_tree().paused = true
	else:
		_results_overlay.visible = false
		get_tree().paused = false

func _refresh_banner_info() -> void:
	if default_banner:
		_banner_title.text = "🌸 " + default_banner.banner_name
		_banner_desc.text = default_banner.description
	
	var coins: int = GameManager.shrine_coins if GameManager else 500
	var pity: int = GameManager.gacha_pity if GameManager else 0
	_coins_label.text = "🪙 Coins: %d   |   🎯 Pity: %d/10" % [coins, pity]

func _on_currency_changed(new_amount: int) -> void:
	_coins_label.text = "🪙 Shrine Coins: %d" % new_amount

func _on_single_pull_pressed() -> void:
	_execute_pulls(1)

func _on_multi_pull_pressed() -> void:
	_execute_pulls(10)

func _execute_pulls(count: int) -> void:
	if not GameManager or not default_banner:
		return

	var results: Array[Dictionary] = GameManager.pull_gacha(default_banner, count)
	if results.is_empty():
		return

	# Clear previous results
	for child in _results_container.get_children():
		child.queue_free()

	for res in results:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)

		var icon_lbl := Label.new()
		icon_lbl.text = "⭐" if res.type == "character" else "⚔️"
		row.add_child(icon_lbl)

		var info_lbl := Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if res.type == "character":
			if res.is_duplicate:
				info_lbl.text = "✨ %s [DUPLICATE] -> %s" % [res.name, res.message]
				info_lbl.modulate = Color(0.85, 0.5, 1.0) # Violet / Epic
			else:
				info_lbl.text = "🌟 %s [NEW CHARACTER UNLOCKED!]" % res.name
				info_lbl.modulate = Color(1.0, 0.85, 0.2) # Gold / Legendary
		else:
			info_lbl.text = "%s" % res.message
			info_lbl.modulate = Color(0.7, 0.9, 1.0) # Cyan / Rare weapon

		row.add_child(info_lbl)
		_results_container.add_child(row)

	_results_overlay.visible = true
