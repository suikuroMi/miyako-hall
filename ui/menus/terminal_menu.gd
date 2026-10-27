# terminal_menu.gd
# Modern anime-ARPG style Terminal / Dashboard Pause Menu (inspired by Wuthering Waves / Genshin).
# Replaces top-bar clutter with a sleek, unified dashboard featuring active character profile,
# quick-launch feature tiles (Convene, Resonators, Quests, Codex, Talents, Expeditions, Synthesis, Photo),
# and system controls.

class_name TerminalMenu
extends PanelContainer

@onready var close_btn: Button = $VBox/HeaderRow/CloseBtn
@onready var char_name_label: Label = $VBox/MainBody/LeftProfile/ProfileVBox/CharName
@onready var char_title_label: Label = $VBox/MainBody/LeftProfile/ProfileVBox/CharTitle
@onready var char_avatar: TextureRect = $VBox/MainBody/LeftProfile/ProfileVBox/AvatarFrame/AvatarTexture
@onready var faith_rank_label: Label = $VBox/MainBody/LeftProfile/ProfileVBox/StatsBox/FaithRank
@onready var shrine_tier_label: Label = $VBox/MainBody/LeftProfile/ProfileVBox/StatsBox/ShrineTier
@onready var coins_label: Label = $VBox/MainBody/LeftProfile/ProfileVBox/StatsBox/Coins
@onready var shards_label: Label = $VBox/MainBody/LeftProfile/ProfileVBox/StatsBox/Shards
@onready var time_label: Label = $VBox/MainBody/LeftProfile/ProfileVBox/StatsBox/TimeStatus

# Grid Tile Buttons
@onready var btn_gacha: Button = $VBox/MainBody/RightGrid/Tiles/BtnGacha
@onready var btn_roster: Button = $VBox/MainBody/RightGrid/Tiles/BtnRoster
@onready var btn_quests: Button = $VBox/MainBody/RightGrid/Tiles/BtnQuests
@onready var btn_archive: Button = $VBox/MainBody/RightGrid/Tiles/BtnArchive
@onready var btn_talents: Button = $VBox/MainBody/RightGrid/Tiles/BtnTalents
@onready var btn_expeditions: Button = $VBox/MainBody/RightGrid/Tiles/BtnExpeditions
@onready var btn_synthesis: Button = $VBox/MainBody/RightGrid/Tiles/BtnSynthesis
@onready var btn_time: Button = $VBox/MainBody/RightGrid/Tiles/BtnTime
@onready var btn_photo: Button = $VBox/MainBody/RightGrid/Tiles/BtnPhoto
@onready var btn_settings: Button = $VBox/MainBody/RightGrid/Tiles/BtnSettings

# Bottom bar buttons
@onready var btn_quit: Button = $VBox/BottomRow/BtnQuit
@onready var btn_main_menu: Button = $VBox/BottomRow/BtnMainMenu
@onready var btn_debug: Button = $VBox/BottomRow/BtnDebug
@onready var btn_resume: Button = $VBox/BottomRow/BtnResume

# Settings sub-modal inside terminal
@onready var settings_submodal: PanelContainer = $SettingsSubmodal
@onready var settings_close_btn: Button = $SettingsSubmodal/VBox/Header/SettingsCloseBtn
@onready var window_mode_btn: Button = $SettingsSubmodal/VBox/WindowModeBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(close_menu)
	if btn_resume:
		btn_resume.pressed.connect(close_menu)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_game)
	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_return_main_menu)
	if btn_debug:
		btn_debug.pressed.connect(func(): _open_sub_view("DebugMenu", "toggle_menu"))

	# Tile connections
	if btn_gacha:
		btn_gacha.pressed.connect(func(): _open_sub_view("GachaMenu", "toggle_menu"))
	if btn_roster:
		btn_roster.pressed.connect(func(): _open_sub_view("CustomizationMenu", "toggle_menu"))
	if btn_quests:
		btn_quests.pressed.connect(func(): _open_sub_view("QuestLog", "toggle_log"))
	if btn_archive:
		btn_archive.pressed.connect(func(): _open_sub_view("HoloArchive", "toggle_archive"))
	if btn_talents:
		btn_talents.pressed.connect(func(): _open_sub_view("TalentTree", "toggle_menu"))
	if btn_expeditions:
		btn_expeditions.pressed.connect(func(): _open_sub_view("ExpeditionBoard", "toggle_board"))
	if btn_synthesis:
		btn_synthesis.pressed.connect(func(): _open_sub_view("CookingStationMenu", "toggle_menu"))
	if btn_photo:
		btn_photo.pressed.connect(func(): _open_sub_view("PhotoMode", "toggle_photo_mode"))
	if btn_time:
		btn_time.pressed.connect(_on_time_tile_pressed)
	if btn_settings:
		btn_settings.pressed.connect(_toggle_settings_submodal)

	if settings_close_btn:
		settings_close_btn.pressed.connect(func(): settings_submodal.visible = false)
	if window_mode_btn:
		window_mode_btn.pressed.connect(_toggle_window_mode)
		_update_window_mode_btn()

	_build_volume_sliders()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if visible:
				if settings_submodal and settings_submodal.visible:
					settings_submodal.visible = false
				else:
					close_menu()
				get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	visible = true
	get_tree().paused = true
	if settings_submodal:
		settings_submodal.visible = false
	_refresh_profile()

func close_menu() -> void:
	visible = false
	get_tree().paused = false

func _open_sub_view(node_name: String, method_name: String) -> void:
	close_menu()
	var target = get_tree().root.find_child(node_name, true, false)
	if is_instance_valid(target) and target.has_method(method_name):
		target.call(method_name)

func _on_time_tile_pressed() -> void:
	if TimeManager:
		TimeManager.advance_time_period()
		_refresh_profile()

func _refresh_profile() -> void:
	if not GameManager:
		return

	var char_id: String = GameManager.active_character_id
	var data: CharacterData = GameManager.get_character_data(char_id)

	if char_name_label:
		char_name_label.text = data.name if data else "Ookami Mio"

	if char_title_label:
		var archetype_name := "Shrine Maiden"
		if data:
			match data.archetype:
				CharacterData.Archetype.SHRINE_MAIDEN: archetype_name = "Shrine Maiden Wolf Spirit"
				CharacterData.Archetype.VANGUARD: archetype_name = "Demon Swordswoman Vanguard"
				CharacterData.Archetype.ASSASSIN: archetype_name = "Blizzard Kitsune Assassin"
				CharacterData.Archetype.REAPER: archetype_name = "Underworld Shinigami Reaper"
				CharacterData.Archetype.MARKSMAN: archetype_name = "Spiritual Talisman Marksman"
		char_title_label.text = archetype_name

	if char_avatar and data and data.icon:
		char_avatar.texture = data.icon

	var rank: int = GameManager.faith_ranks.get(char_id, 0)
	if faith_rank_label:
		faith_rank_label.text = "⭐ Faith Resonance: Rank %d" % rank

	if shrine_tier_label:
		shrine_tier_label.text = "⛩️ Sanctuary Level: Tier %d" % GameManager.shrine_tier

	if coins_label:
		coins_label.text = "💰 Shrine Coins: %d" % GameManager.shrine_coins

	var shards: int = GameManager.character_shards.get(char_id, 0)
	if shards_label:
		shards_label.text = "✨ Awakening Shards: %d" % shards

	if time_label and TimeManager:
		var icon := "🌑 " if TimeManager.is_eclipse else "☀️ "
		time_label.text = "%sTime of Day: %s" % [icon, TimeManager.get_period_name()]

	if btn_time and TimeManager:
		var icon := "🌑 " if TimeManager.is_eclipse else "☀️ "
		btn_time.text = "%s Time (T)\n%s" % [icon, TimeManager.get_period_name()]

func _toggle_settings_submodal() -> void:
	if settings_submodal:
		settings_submodal.visible = not settings_submodal.visible
		_update_window_mode_btn()

func _toggle_window_mode() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_update_window_mode_btn()

func _update_window_mode_btn() -> void:
	if not window_mode_btn:
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		window_mode_btn.text = "Display: Fullscreen"
	else:
		window_mode_btn.text = "Display: Windowed"

func _build_volume_sliders() -> void:
	if not settings_submodal:
		return
	var sliders_box: VBoxContainer = settings_submodal.get_node_or_null("VBox/SlidersBox")
	if not sliders_box:
		return
	for c in sliders_box.get_children():
		c.queue_free()

	_add_vol_row(sliders_box, "Master Vol", func(): return AudioManager.master_volume if AudioManager else 0.8, func(v):
		if AudioManager: AudioManager.set_master_volume(v)
	)
	_add_vol_row(sliders_box, "Music (BGM)", func(): return AudioManager.bgm_volume if AudioManager else 0.7, func(v):
		if AudioManager: AudioManager.set_bgm_volume(v)
	)
	_add_vol_row(sliders_box, "Sound (SFX)", func(): return AudioManager.sfx_volume if AudioManager else 0.85, func(v):
		if AudioManager:
			AudioManager.set_sfx_volume(v)
			AudioManager.play_sfx("coin")
	)

func _add_vol_row(parent: Control, label_text: String, get_val_fn: Callable, set_val_fn: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = get_val_fn.call() * 100.0
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(slider.value)
	val_lbl.custom_minimum_size = Vector2(36, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(new_val: float):
		val_lbl.text = "%d%%" % int(new_val)
		set_val_fn.call(new_val / 100.0)
	)

func _on_return_main_menu() -> void:
	get_tree().paused = false
	if SceneManager:
		SceneManager.transition_to_map("res://ui/menus/main_menu.tscn", "default")
	else:
		get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")

func _on_quit_game() -> void:
	get_tree().quit()
