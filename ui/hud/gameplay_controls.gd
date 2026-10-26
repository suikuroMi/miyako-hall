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

# Controller / Gamepad & UI state
var _is_gamepad_mode: bool = false
var _attack_hint: Label = null

# Party HUD
var _party_buttons: Array[Button] = []
var _party_bar: HBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_terminal_trigger()
	_build_party_bar()
	_build_skill_placeholders()
	_build_dummy_controls()

	if EventBus:
		EventBus.skill_cooldown_updated.connect(_on_skill_cooldown_updated)
		EventBus.skill_cast.connect(_on_skill_cast)

	if GameManager:
		GameManager.party_swapped.connect(_on_party_swapped)
		GameManager.party_composition_changed.connect(_on_party_composition_changed)

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if Input.get_connected_joypads().size() > 0:
		_set_gamepad_mode(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if not _is_gamepad_mode:
			_set_gamepad_mode(true)
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_START:
					_toggle_settings_menu()
					get_viewport().set_input_as_handled()
				JOY_BUTTON_BACK:
					_toggle_quest_log()
					get_viewport().set_input_as_handled()
				JOY_BUTTON_A:
					_on_dash_button_pressed()
				JOY_BUTTON_X:
					_on_skill_button_pressed("Q")
				JOY_BUTTON_Y:
					_on_skill_button_pressed("E")
				JOY_BUTTON_B:
					_on_skill_button_pressed("R")
				JOY_BUTTON_LEFT_SHOULDER:
					if GameManager and GameManager.active_party.size() > 0:
						var prev_idx: int = (GameManager.active_party_index - 1 + GameManager.active_party.size()) % GameManager.active_party.size()
						GameManager.swap_to_party_slot(prev_idx)
				JOY_BUTTON_RIGHT_SHOULDER:
					if GameManager and GameManager.active_party.size() > 0:
						var next_idx: int = (GameManager.active_party_index + 1) % GameManager.active_party.size()
						GameManager.swap_to_party_slot(next_idx)
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.4:
		if not _is_gamepad_mode:
			_set_gamepad_mode(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		if _is_gamepad_mode:
			_set_gamepad_mode(false)
		if event.physical_keycode == KEY_ESCAPE:
			_toggle_settings_menu()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_O:
			_toggle_cooking_station()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if _is_gamepad_mode:
			_set_gamepad_mode(false)

# ---------------------------------------------------------------------------
# Terminal / Menu Trigger (Clean Top Header)
# ---------------------------------------------------------------------------

func _build_terminal_trigger() -> void:
	var menu_btn := Button.new()
	menu_btn.text = "❖ Terminal (Esc)"
	menu_btn.position = Vector2(324, 14)
	menu_btn.custom_minimum_size = Vector2(130, 30)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	style.border_color = Color(0.8, 0.65, 0.28, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	menu_btn.add_theme_stylebox_override("normal", style)
	menu_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	menu_btn.add_theme_font_size_override("font_size", 12)

	menu_btn.pressed.connect(_toggle_terminal_menu)
	add_child(menu_btn)

func _toggle_terminal_menu() -> void:
	var terminal = get_tree().root.find_child("TerminalMenu", true, false)
	if is_instance_valid(terminal) and terminal.has_method("toggle_menu"):
		terminal.toggle_menu()

func _toggle_settings_menu() -> void:
	_toggle_terminal_menu()

func _exit_tree() -> void:
	if Input and Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)

func _toggle_quest_log() -> void:
	var ql = get_tree().root.find_child("QuestLog", true, false)
	if is_instance_valid(ql) and ql.has_method("toggle_log"):
		ql.toggle_log()

func _toggle_holo_archive() -> void:
	var ha = get_tree().root.find_child("HoloArchive", true, false)
	if is_instance_valid(ha) and ha.has_method("toggle_archive"):
		ha.toggle_archive()

func _toggle_gacha_menu() -> void:
	var gacha = get_tree().root.find_child("GachaMenu", true, false)
	if is_instance_valid(gacha) and gacha.has_method("toggle_menu"):
		gacha.toggle_menu()

func _toggle_customization_menu() -> void:
	var roster = get_tree().root.find_child("CustomizationMenu", true, false)
	if is_instance_valid(roster) and roster.has_method("toggle_menu"):
		roster.toggle_menu()

func _toggle_talent_tree() -> void:
	var tt = get_tree().root.find_child("TalentTree", true, false)
	if is_instance_valid(tt) and tt.has_method("toggle_menu"):
		tt.toggle_menu()

func _toggle_expedition_board() -> void:
	var eb = get_tree().root.find_child("ExpeditionBoard", true, false)
	if is_instance_valid(eb) and eb.has_method("toggle_board"):
		eb.toggle_board()

func _toggle_photo_mode() -> void:
	var pm = get_tree().root.find_child("PhotoMode", true, false)
	if is_instance_valid(pm) and pm.has_method("toggle_photo_mode"):
		pm.toggle_photo_mode()

func _toggle_cooking_station() -> void:
	var cook = get_tree().root.find_child("CookingStationMenu", true, false)
	if is_instance_valid(cook) and cook.has_method("toggle_menu"):
		cook.toggle_menu()

# ---------------------------------------------------------------------------
# Party HUD (Quick-Swap Bar underneath Stats HUD)
# ---------------------------------------------------------------------------

func _build_party_bar() -> void:
	_party_bar = HBoxContainer.new()
	_party_bar.position = Vector2(68, 114)
	_party_bar.add_theme_constant_override("separation", 8)
	add_child(_party_bar)
	_refresh_party_bar()

func _refresh_party_bar() -> void:
	if not _party_bar or not GameManager:
		return

	for child in _party_bar.get_children():
		child.queue_free()
	_party_buttons.clear()

	var active_party: Array[String] = GameManager.active_party
	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(136, 36)

		if i < active_party.size():
			var char_id: String = active_party[i]
			var char_data: CharacterData = GameManager.get_character_data(char_id)
			var display_name: String = char_data.name if char_data else char_id
			btn.text = "[%d] %s" % [i + 1, display_name]

			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(6)
			if i == GameManager.active_party_index:
				style.bg_color = Color(0.25, 0.2, 0.08, 0.95)
				style.border_color = Color(1.0, 0.85, 0.35, 1.0)
				style.set_border_width_all(2)
			else:
				style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
				style.border_color = Color(0.35, 0.35, 0.4, 0.8)
				style.set_border_width_all(1)

			btn.add_theme_stylebox_override("normal", style)
			btn.pressed.connect(func(): GameManager.swap_to_party_slot(i))
		else:
			btn.text = "[%d] Empty" % (i + 1)
			btn.disabled = true

		_party_bar.add_child(btn)
		_party_buttons.append(btn)

func _on_party_swapped(_slot_idx: int, _char_data: Resource) -> void:
	_refresh_party_bar()

func _on_party_composition_changed(_party: Array) -> void:
	_refresh_party_bar()

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
	attack_hint.text = "1/2/3: Swap Party   |   Space: Dash   |   Q/E/R: Skills   |   R-Click: Attack"
	attack_hint.anchor_left = 0.5
	attack_hint.anchor_top = 1.0
	attack_hint.anchor_right = 0.5
	attack_hint.anchor_bottom = 1.0
	attack_hint.offset_left = -230
	attack_hint.offset_top = -108
	attack_hint.offset_right = 230
	attack_hint.offset_bottom = -82
	attack_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attack_hint = attack_hint
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

func _set_gamepad_mode(enabled: bool) -> void:
	if _is_gamepad_mode == enabled and _attack_hint != null:
		return
	_is_gamepad_mode = enabled

	if _is_gamepad_mode:
		_skill_labels["DASH"] = "Dash (A)"
		_skill_labels["Q"] = "X: Skill 1"
		_skill_labels["E"] = "Y: Skill 2"
		_skill_labels["R"] = "B: Ult"
		if _attack_hint:
			_attack_hint.text = "LB/RB: Swap Party   |   [A]: Dash   |   [X]/[Y]/[B]: Skills   |   [RT]: Attack"
	else:
		_skill_labels["DASH"] = "Dash (Space)"
		_skill_labels["Q"] = "Q: Skill 1"
		_skill_labels["E"] = "E: Skill 2"
		_skill_labels["R"] = "R: Ult"
		if _attack_hint:
			_attack_hint.text = "1/2/3: Swap Party   |   Space: Dash   |   Q/E/R: Skills   |   R-Click: Attack"

	for k in ["DASH", "Q", "E", "R"]:
		if _skill_buttons.has(k) and not _skill_buttons[k].disabled:
			_skill_buttons[k].text = _skill_labels.get(k, k)

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		_set_gamepad_mode(true)
	elif Input.get_connected_joypads().size() == 0:
		_set_gamepad_mode(false)

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
