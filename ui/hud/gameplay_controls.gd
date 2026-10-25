extends Control

const DUMMY_SCENE: PackedScene = preload("res://entities/enemy/training_dummy/training_dummy.tscn")

var _dummy_mode: OptionButton
var _dummy_panel: PanelContainer
var _spawn_count := 0
var _skill_buttons: Dictionary = {}
var _skill_labels: Dictionary = {
	"DASH": "Dash (Space)",
	"Q": "Q: Skill 1",
	"E": "E: Skill 2",
	"R": "R: Ult"
}

# Settings menu modal
var _settings_panel: PanelContainer
var _window_mode_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_top_bar()
	_build_settings_menu()
	_build_skill_placeholders()
	_build_dummy_controls()

	if EventBus:
		EventBus.skill_cooldown_updated.connect(_on_skill_cooldown_updated)
		EventBus.skill_cast.connect(_on_skill_cast)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_toggle_settings_menu()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Top Bar (Centered, avoids HealthBar & StatsHUD on the left, Minimap on right)
# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.offset_left = -210
	top_bar.offset_right = 210
	top_bar.offset_top = 18
	top_bar.offset_bottom = 60
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	var settings_btn := Button.new()
	settings_btn.text = "⚙️ Settings (Esc)"
	settings_btn.custom_minimum_size = Vector2(130, 42)
	top_bar.add_child(settings_btn)
	settings_btn.pressed.connect(_toggle_settings_menu)

	var gacha_btn := Button.new()
	gacha_btn.text = "🌸 Gacha (G)"
	gacha_btn.custom_minimum_size = Vector2(120, 42)
	top_bar.add_child(gacha_btn)
	gacha_btn.pressed.connect(_toggle_gacha_menu)

	var roster_btn := Button.new()
	roster_btn.text = "⛩️ Roster (C)"
	roster_btn.custom_minimum_size = Vector2(120, 42)
	top_bar.add_child(roster_btn)
	roster_btn.pressed.connect(_toggle_customization_menu)

func _toggle_gacha_menu() -> void:
	var gacha = get_tree().root.find_child("GachaMenu", true, false)
	if is_instance_valid(gacha) and gacha.has_method("toggle_menu"):
		gacha.toggle_menu()

func _toggle_customization_menu() -> void:
	var roster = get_tree().root.find_child("CustomizationMenu", true, false)
	if is_instance_valid(roster) and roster.has_method("toggle_menu"):
		roster.toggle_menu()

# ---------------------------------------------------------------------------
# Settings & Pause Menu Modal
# ---------------------------------------------------------------------------

func _build_settings_menu() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_panel.anchor_left = 0.5
	_settings_panel.anchor_right = 0.5
	_settings_panel.anchor_top = 0.5
	_settings_panel.anchor_bottom = 0.5
	_settings_panel.offset_left = -190
	_settings_panel.offset_right = 190
	_settings_panel.offset_top = -210
	_settings_panel.offset_bottom = 210
	_settings_panel.visible = false

	# Dark styled panel
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style_box.border_color = Color(0.7, 0.55, 0.25, 1.0)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(10)
	style_box.content_margin_left = 24
	style_box.content_margin_right = 24
	style_box.content_margin_top = 20
	style_box.content_margin_bottom = 20
	_settings_panel.add_theme_stylebox_override("panel", style_box)
	add_child(_settings_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(col)

	var title := Label.new()
	title.text = "PAUSE & SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	col.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Resume Game"
	resume_btn.custom_minimum_size = Vector2(0, 42)
	resume_btn.pressed.connect(_close_settings_menu)
	col.add_child(resume_btn)

	_window_mode_btn = Button.new()
	_update_window_mode_button_text()
	_window_mode_btn.custom_minimum_size = Vector2(0, 42)
	_window_mode_btn.pressed.connect(_toggle_window_mode)
	col.add_child(_window_mode_btn)

	var main_menu_btn := Button.new()
	main_menu_btn.text = "Return to Main Menu"
	main_menu_btn.custom_minimum_size = Vector2(0, 42)
	main_menu_btn.pressed.connect(_return_to_main_menu)
	col.add_child(main_menu_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit to Desktop"
	quit_btn.custom_minimum_size = Vector2(0, 42)
	quit_btn.pressed.connect(_quit_game)
	col.add_child(quit_btn)

func _toggle_settings_menu() -> void:
	if _settings_panel.visible:
		_close_settings_menu()
	else:
		_open_settings_menu()

func _open_settings_menu() -> void:
	_update_window_mode_button_text()
	_settings_panel.visible = true
	get_tree().paused = true

func _close_settings_menu() -> void:
	_settings_panel.visible = false
	get_tree().paused = false

func _toggle_window_mode() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_update_window_mode_button_text()

func _update_window_mode_button_text() -> void:
	if not _window_mode_btn:
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		_window_mode_btn.text = "Screen: Fullscreen"
	else:
		_window_mode_btn.text = "Screen: Windowed"

func _return_to_main_menu() -> void:
	get_tree().paused = false
	if SceneManager:
		SceneManager.transition_to_map("res://ui/menus/main_menu.tscn", "default")
	else:
		get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")

func _quit_game() -> void:
	get_tree().quit()

# ---------------------------------------------------------------------------
# Skills & Combat HUD (Bottom Center)
# ---------------------------------------------------------------------------

func _build_skill_placeholders() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_top = 1.0
	row.anchor_right = 0.5
	row.anchor_bottom = 1.0
	row.offset_left = -230
	row.offset_top = -76
	row.offset_right = 230
	row.offset_bottom = -24
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	# Dedicated Dash button
	var dash_btn := Button.new()
	dash_btn.text = "Dash (Space)"
	dash_btn.custom_minimum_size = Vector2(108, 48)
	row.add_child(dash_btn)
	_skill_buttons["DASH"] = dash_btn
	dash_btn.pressed.connect(_on_dash_button_pressed)

	for key in ["Q", "E", "R"]:
		var button := Button.new()
		button.text = _skill_labels.get(key, key)
		button.custom_minimum_size = Vector2(108, 48)
		row.add_child(button)
		_skill_buttons[key] = button
		button.pressed.connect(_on_skill_button_pressed.bind(key))

	var attack_hint := Label.new()
	attack_hint.text = "Space / Shift: Dash   |   Q/E/R: Skills   |   Right click: Attack"
	attack_hint.anchor_left = 0.5
	attack_hint.anchor_top = 1.0
	attack_hint.anchor_right = 0.5
	attack_hint.anchor_bottom = 1.0
	attack_hint.offset_left = -230
	attack_hint.offset_top = -108
	attack_hint.offset_right = 230
	attack_hint.offset_bottom = -82
	attack_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(attack_hint)

func _on_dash_button_pressed() -> void:
	var player = get_tree().root.find_child("Player", true, false)
	if is_instance_valid(player) and player.has_method("dash"):
		player.dash()

func _on_skill_button_pressed(slot: String) -> void:
	var player = get_tree().root.find_child("Player", true, false)
	if is_instance_valid(player) and "skill_caster" in player and is_instance_valid(player.skill_caster):
		player.skill_caster.cast_skill(slot)

func _on_skill_cooldown_updated(slot: String, current_cooldown: float, _max_cooldown: float) -> void:
	slot = slot.to_upper()
	if not _skill_buttons.has(slot):
		return
	var btn: Button = _skill_buttons[slot]
	if current_cooldown > 0.05:
		btn.text = "%s (%.1fs)" % [slot, current_cooldown]
		btn.disabled = true
	else:
		btn.text = _skill_labels.get(slot, slot)
		btn.disabled = false

func _on_skill_cast(slot: String, skill_data: Resource) -> void:
	slot = slot.to_upper()
	if skill_data and "display_name" in skill_data:
		_skill_labels[slot] = "%s: %s" % [slot, skill_data.display_name]
		if _skill_buttons.has(slot):
			_skill_buttons[slot].text = _skill_labels[slot]

# ---------------------------------------------------------------------------
# Dummy Controls (Bottom-Left Corner)
# ---------------------------------------------------------------------------

func _build_dummy_controls() -> void:
	var config_button := Button.new()
	config_button.text = "🎯 Dummy Setup"
	config_button.anchor_left = 0.0
	config_button.anchor_right = 0.0
	config_button.anchor_top = 1.0
	config_button.anchor_bottom = 1.0
	config_button.offset_left = 24
	config_button.offset_right = 160
	config_button.offset_top = -68
	config_button.offset_bottom = -24
	add_child(config_button)
	config_button.pressed.connect(_toggle_dummy_panel)

	_dummy_panel = PanelContainer.new()
	_dummy_panel.anchor_left = 0.0
	_dummy_panel.anchor_right = 0.0
	_dummy_panel.anchor_top = 1.0
	_dummy_panel.anchor_bottom = 1.0
	_dummy_panel.offset_left = 24
	_dummy_panel.offset_right = 290
	_dummy_panel.offset_top = -290
	_dummy_panel.offset_bottom = -76
	_dummy_panel.visible = false
	add_child(_dummy_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_dummy_panel.add_child(column)

	var title := Label.new()
	title.text = "Training Dummies"
	column.add_child(title)

	_dummy_mode = OptionButton.new()
	_dummy_mode.add_item("Standing", TrainingDummy.Behavior.STANDING)
	_dummy_mode.add_item("Chasing", TrainingDummy.Behavior.CHASING)
	_dummy_mode.add_item("Chasing + attacking", TrainingDummy.Behavior.CHASING_AND_ATTACKING)
	_dummy_mode.select(0)
	column.add_child(_dummy_mode)

	var spawn_button := Button.new()
	spawn_button.text = "Spawn dummy (100 HP)"
	column.add_child(spawn_button)
	spawn_button.pressed.connect(_spawn_dummy)

	var clear_button := Button.new()
	clear_button.text = "Clear dummies"
	column.add_child(clear_button)
	clear_button.pressed.connect(_clear_dummies)

func _toggle_dummy_panel() -> void:
	_dummy_panel.visible = not _dummy_panel.visible

func _spawn_dummy() -> void:
	var player := get_tree().root.find_child("Player", true, false) as Node2D
	if not is_instance_valid(player):
		return
	var dummy := DUMMY_SCENE.instantiate() as TrainingDummy
	dummy.configure(_dummy_mode.get_selected_id())
	dummy.global_position = player.global_position + Vector2(90 + (_spawn_count % 4) * 34, 0).rotated(float(_spawn_count / 4) * 0.65)
	get_tree().current_scene.add_child(dummy)
	_spawn_count += 1

func _clear_dummies() -> void:
	for dummy in get_tree().get_nodes_in_group("training_dummies"):
		dummy.queue_free()
	_spawn_count = 0
