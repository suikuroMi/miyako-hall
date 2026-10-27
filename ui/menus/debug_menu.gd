# debug_menu.gd
# In-Game Developer Debug Console for testing and rapid verification.
# Allows live toggling of God Mode, unlimited skills, character switching,
# enemy spawning, map warps, economic cheats, and time/save controls.

class_name DebugMenu
extends PanelContainer

# ---------------------------------------------------------------------------
# Preloaded scenes and resources
# ---------------------------------------------------------------------------
const SCENE_DUMMY: PackedScene = preload("res://entities/enemy/training_dummy/training_dummy.tscn")
const SCENE_CHASER: PackedScene = preload("res://entities/enemy/basic_chaser/basic_chaser.tscn")
const SCENE_SLIME: PackedScene = preload("res://entities/enemy/slime/slime.tscn")
const SCENE_BOSS_AYAME: PackedScene = preload("res://entities/enemy/boss/boss_nakiri_ayame.tscn")
const SCENE_BOSS_FUBUKI: PackedScene = preload("res://entities/enemy/boss/boss_shirakami_fubuki.tscn")

const RES_SCYTHE: Resource = preload("res://data/weapons/scythe.tres")
const RES_TALISMAN: Resource = preload("res://data/weapons/talisman.tres")
const RES_SPIRIT_BLADE: Resource = preload("res://data/weapons/spirit_blade.tres")

# ---------------------------------------------------------------------------
# Header & Footer UI references
# ---------------------------------------------------------------------------
@onready var close_btn: Button = $VBox/HeaderRow/CloseBtn
@onready var pause_check: CheckBox = $VBox/HeaderRow/PauseCheck
@onready var perf_label: Label = $VBox/HeaderRow/PerfLabel
@onready var status_label: Label = $VBox/FooterRow/StatusLabel

# Tab 1: Player & Combat Controls
@onready var btn_god_mode: Button = $VBox/TabContainer/Player/Grid/Row1/BtnGodMode
@onready var btn_full_heal: Button = $VBox/TabContainer/Player/Grid/Row1/BtnFullHeal
@onready var btn_inf_skills: Button = $VBox/TabContainer/Player/Grid/Row1/BtnInfSkills
@onready var btn_speed_1x: Button = $VBox/TabContainer/Player/Grid/SpeedBox/BtnSpeed1x
@onready var btn_speed_15x: Button = $VBox/TabContainer/Player/Grid/SpeedBox/BtnSpeed15x
@onready var btn_speed_2x: Button = $VBox/TabContainer/Player/Grid/SpeedBox/BtnSpeed2x
@onready var btn_speed_3x: Button = $VBox/TabContainer/Player/Grid/SpeedBox/BtnSpeed3x
@onready var btn_exp_500: Button = $VBox/TabContainer/Player/Grid/RowExp/BtnExp500
@onready var btn_exp_2500: Button = $VBox/TabContainer/Player/Grid/RowExp/BtnExp2500
@onready var btn_level_1: Button = $VBox/TabContainer/Player/Grid/RowExp/BtnLevel1
@onready var btn_level_5: Button = $VBox/TabContainer/Player/Grid/RowExp/BtnLevel5
@onready var btn_trigger_draft: Button = $VBox/TabContainer/Player/Grid/BtnTriggerDraft
@onready var btn_equip_scythe: Button = $VBox/TabContainer/Player/Grid/WeaponBox/BtnEquipScythe
@onready var btn_equip_talisman: Button = $VBox/TabContainer/Player/Grid/WeaponBox/BtnEquipTalisman
@onready var btn_equip_blade: Button = $VBox/TabContainer/Player/Grid/WeaponBox/BtnEquipBlade

# Tab 2: Roster & Economy
@onready var btn_unlock_all: Button = $VBox/TabContainer/Roster/Grid/BtnUnlockAll
@onready var btn_swap_mio: Button = $VBox/TabContainer/Roster/Grid/SwapBox/BtnSwapMio
@onready var btn_swap_fubuki: Button = $VBox/TabContainer/Roster/Grid/SwapBox/BtnSwapFubuki
@onready var btn_swap_ayame: Button = $VBox/TabContainer/Roster/Grid/SwapBox/BtnSwapAyame
@onready var btn_coins_1000: Button = $VBox/TabContainer/Roster/Grid/RowCoins/BtnCoins1000
@onready var btn_coins_10000: Button = $VBox/TabContainer/Roster/Grid/RowCoins/BtnCoins10000
@onready var btn_shards_50: Button = $VBox/TabContainer/Roster/Grid/RowCoins/BtnShards50
@onready var btn_awaken_all: Button = $VBox/TabContainer/Roster/Grid/RowCoins/BtnAwakenAll
@onready var btn_shrine_tier: Button = $VBox/TabContainer/Roster/Grid/RowUpgrades/BtnShrineTier
@onready var btn_max_talents: Button = $VBox/TabContainer/Roster/Grid/RowUpgrades/BtnMaxTalents
@onready var btn_gacha_pity: Button = $VBox/TabContainer/Roster/Grid/RowUpgrades/BtnGachaPity

# Tab 3: Fast Travel & Warps
@onready var btn_warp_shrine: Button = $VBox/TabContainer/Warps/Grid/RowWarp1/BtnWarpShrine
@onready var btn_warp_forest: Button = $VBox/TabContainer/Warps/Grid/RowWarp1/BtnWarpForest
@onready var btn_warp_dojo: Button = $VBox/TabContainer/Warps/Grid/RowWarp2/BtnWarpDojo
@onready var btn_warp_blizzard: Button = $VBox/TabContainer/Warps/Grid/RowWarp2/BtnWarpBlizzard
@onready var btn_warp_endless: Button = $VBox/TabContainer/Warps/Grid/RowWarp2/BtnWarpEndless
@onready var btn_reload_map: Button = $VBox/TabContainer/Warps/Grid/BtnReloadMap

# Tab 4: Combat & Spawner
@onready var btn_spawn_dummy_idle: Button = $VBox/TabContainer/Combat/Grid/RowDummy/BtnSpawnDummyIdle
@onready var btn_spawn_dummy_atk: Button = $VBox/TabContainer/Combat/Grid/RowDummy/BtnSpawnDummyAtk
@onready var btn_spawn_dummy_move: Button = $VBox/TabContainer/Combat/Grid/RowDummy/BtnSpawnDummyMove
@onready var btn_spawn_chaser: Button = $VBox/TabContainer/Combat/Grid/RowEnemies/BtnSpawnChaser
@onready var btn_spawn_slime: Button = $VBox/TabContainer/Combat/Grid/RowEnemies/BtnSpawnSlime
@onready var btn_spawn_ayame_boss: Button = $VBox/TabContainer/Combat/Grid/RowEnemies/BtnSpawnAyameBoss
@onready var btn_spawn_fubuki_boss: Button = $VBox/TabContainer/Combat/Grid/RowEnemies/BtnSpawnFubukiBoss
@onready var btn_kill_all_enemies: Button = $VBox/TabContainer/Combat/Grid/RowActions/BtnKillAllEnemies
@onready var btn_start_siege: Button = $VBox/TabContainer/Combat/Grid/RowActions/BtnStartSiege

# Tab 5: World & Saves
@onready var btn_time_dawn: Button = $VBox/TabContainer/World/Grid/TimeBox/BtnDawn
@onready var btn_time_noon: Button = $VBox/TabContainer/World/Grid/TimeBox/BtnNoon
@onready var btn_time_dusk: Button = $VBox/TabContainer/World/Grid/TimeBox/BtnDusk
@onready var btn_time_midnight: Button = $VBox/TabContainer/World/Grid/TimeBox/BtnMidnight
@onready var btn_time_eclipse: Button = $VBox/TabContainer/World/Grid/BtnEclipse
@onready var btn_quick_save: Button = $VBox/TabContainer/World/Grid/RowSave/BtnQuickSave
@onready var btn_quick_load: Button = $VBox/TabContainer/World/Grid/RowSave/BtnQuickLoad
@onready var btn_reset_save: Button = $VBox/TabContainer/World/Grid/RowSave/BtnResetSave

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var _god_mode_active: bool = false
var _inf_skills_active: bool = false
var _perf_timer: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(close_menu)

	_setup_tab_player()
	_setup_tab_roster()
	_setup_tab_warps()
	_setup_tab_combat()
	_setup_tab_world()

	_set_status("Debug console ready. Press F1 or ~ to toggle.")

func _process(delta: float) -> void:
	if not visible:
		return

	_perf_timer += delta
	if _perf_timer >= 0.35:
		_perf_timer = 0.0
		_update_performance_readout()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1 or event.physical_keycode == KEY_QUOTELEFT:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and visible:
			close_menu()
			get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	visible = true
	if pause_check and pause_check.button_pressed:
		get_tree().paused = true
	_sync_state_to_ui()
	_update_performance_readout()
	_set_status("Console opened.")

func close_menu() -> void:
	visible = false
	if pause_check and pause_check.button_pressed:
		get_tree().paused = false

func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = "Status: " + msg

# ---------------------------------------------------------------------------
# Setup Tab 1: Player & Combat
# ---------------------------------------------------------------------------

func _setup_tab_player() -> void:
	if btn_god_mode:
		btn_god_mode.pressed.connect(_toggle_god_mode)
	if btn_full_heal:
		btn_full_heal.pressed.connect(_on_full_heal)
	if btn_inf_skills:
		btn_inf_skills.pressed.connect(_toggle_inf_skills)

	if btn_speed_1x:
		btn_speed_1x.pressed.connect(func(): _set_player_speed(1.0))
	if btn_speed_15x:
		btn_speed_15x.pressed.connect(func(): _set_player_speed(1.5))
	if btn_speed_2x:
		btn_speed_2x.pressed.connect(func(): _set_player_speed(2.0))
	if btn_speed_3x:
		btn_speed_3x.pressed.connect(func(): _set_player_speed(3.0))

	if btn_exp_500:
		btn_exp_500.pressed.connect(func(): _add_player_exp(500))
	if btn_exp_2500:
		btn_exp_2500.pressed.connect(func(): _add_player_exp(2500))
	if btn_level_1:
		btn_level_1.pressed.connect(func(): _add_player_levels(1))
	if btn_level_5:
		btn_level_5.pressed.connect(func(): _add_player_levels(5))

	if btn_trigger_draft:
		btn_trigger_draft.pressed.connect(_trigger_card_draft)

	if btn_equip_scythe:
		btn_equip_scythe.pressed.connect(func(): _equip_weapon(RES_SCYTHE))
	if btn_equip_talisman:
		btn_equip_talisman.pressed.connect(func(): _equip_weapon(RES_TALISMAN))
	if btn_equip_blade:
		btn_equip_blade.pressed.connect(func(): _equip_weapon(RES_SPIRIT_BLADE))

func _get_player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D

func _toggle_god_mode() -> void:
	_god_mode_active = not _god_mode_active
	var p := _get_player()
	if p:
		p.is_god_mode = _god_mode_active
	btn_god_mode.text = "🛡️ God Mode: " + ("ON" if _god_mode_active else "OFF")
	btn_god_mode.modulate = Color(0.4, 1.2, 0.4) if _god_mode_active else Color(1, 1, 1)
	_set_status("God Mode set to " + ("ON" if _god_mode_active else "OFF"))

func _on_full_heal() -> void:
	var p := _get_player()
	if p and p.has_node("StatsComponent"):
		var stats: StatsComponent = p.get_node("StatsComponent")
		stats.heal_full()
		stats.add_faith(100.0)
		_set_status("Player restored to 100% HP & Full Faith.")
	else:
		_set_status("No player found to heal.")

func _toggle_inf_skills() -> void:
	_inf_skills_active = not _inf_skills_active
	var p := _get_player()
	if p and p.has_node("SkillCasterComponent"):
		var caster: SkillCasterComponent = p.get_node("SkillCasterComponent")
		caster.no_cooldowns = _inf_skills_active
		if _inf_skills_active:
			caster.reset_all_cooldowns()
	btn_inf_skills.text = "⚡ Instant Skills: " + ("ON" if _inf_skills_active else "OFF")
	btn_inf_skills.modulate = Color(0.4, 1.2, 0.4) if _inf_skills_active else Color(1, 1, 1)
	_set_status("Instant Skills set to " + ("ON" if _inf_skills_active else "OFF"))

func _set_player_speed(mult: float) -> void:
	var p := _get_player()
	if p:
		p.speed_multiplier = mult
		_set_status("Player movement speed set to %.1fx" % mult)

func _add_player_exp(amount: int) -> void:
	var p := _get_player()
	if p and p.has_method("add_experience"):
		p.add_experience(amount)
		_set_status("Granted +%d EXP." % amount)

func _add_player_levels(count: int) -> void:
	var p := _get_player()
	if p and p.has_node("StatsComponent"):
		var stats: StatsComponent = p.get_node("StatsComponent")
		for i in range(count):
			var needed: int = stats.exp_to_next_level - stats.current_exp
			stats.add_experience(needed)
		_set_status("Leveled up +%d times." % count)

func _trigger_card_draft() -> void:
	var p := _get_player()
	if p and p.has_node("StatsComponent"):
		var stats: StatsComponent = p.get_node("StatsComponent")
		stats.pending_level_up_choices += 1
		stats.level_up_choices_changed.emit(stats.pending_level_up_choices)
		_set_status("Triggered 3-Card Level Up Draft.")

func _equip_weapon(res: Resource) -> void:
	var p := _get_player()
	if p and p.has_method("equip_weapon"):
		p.equip_weapon(res)
		_set_status("Equipped %s." % (res.get("display_name") if res and "display_name" in res else "Weapon"))

# ---------------------------------------------------------------------------
# Setup Tab 2: Roster & Economy
# ---------------------------------------------------------------------------

func _setup_tab_roster() -> void:
	if btn_unlock_all:
		btn_unlock_all.pressed.connect(_on_unlock_all_characters)
	if btn_swap_mio:
		btn_swap_mio.pressed.connect(func(): _swap_to_character("ookami_mio"))
	if btn_swap_fubuki:
		btn_swap_fubuki.pressed.connect(func(): _swap_to_character("shirakami_fubuki"))
	if btn_swap_ayame:
		btn_swap_ayame.pressed.connect(func(): _swap_to_character("nakiri_ayame"))

	if btn_coins_1000:
		btn_coins_1000.pressed.connect(func(): _add_coins(1000))
	if btn_coins_10000:
		btn_coins_10000.pressed.connect(func(): _add_coins(10000))

	if btn_shards_50:
		btn_shards_50.pressed.connect(_add_50_all_shards)
	if btn_awaken_all:
		btn_awaken_all.pressed.connect(_add_awakening_all)
	if btn_shrine_tier:
		btn_shrine_tier.pressed.connect(_upgrade_shrine_tier)
	if btn_max_talents:
		btn_max_talents.pressed.connect(_max_all_talents)
	if btn_gacha_pity:
		btn_gacha_pity.pressed.connect(_force_gacha_pity)

func _on_unlock_all_characters() -> void:
	if GameManager:
		for cid in ["ookami_mio", "shirakami_fubuki", "nakiri_ayame"]:
			GameManager.unlock_character(cid)
		_set_status("Unlocked Mio, Fubuki, and Ayame.")

func _swap_to_character(char_id: String) -> void:
	if not GameManager:
		return
	if not GameManager.unlocked_characters.has(char_id):
		GameManager.unlock_character(char_id)

	var slot := GameManager.active_party.find(char_id)
	if slot != -1:
		GameManager.swap_to_party_slot(slot)
	else:
		GameManager.set_party_slot(0, char_id)
		GameManager.swap_to_party_slot(0)
	_set_status("Swapped active character to " + char_id.capitalize())

func _add_coins(amount: int) -> void:
	if GameManager:
		GameManager.add_shrine_coins(amount)
		_set_status("Added +%d Shrine Coins (Total: %d)." % [amount, GameManager.shrine_coins])

func _add_50_all_shards() -> void:
	if GameManager:
		for cid in ["ookami_mio", "shirakami_fubuki", "nakiri_ayame"]:
			GameManager.add_character_shards(cid, 50)
		_set_status("Added +50 Shards to all Holomembers.")

func _add_awakening_all() -> void:
	if GameManager:
		for cid in ["ookami_mio", "shirakami_fubuki", "nakiri_ayame"]:
			var curr: int = GameManager.character_awakenings.get(cid, 0)
			GameManager.character_awakenings[cid] = min(curr + 1, 6)
		_set_status("Increased Faith Awakening rank for all characters.")

func _upgrade_shrine_tier() -> void:
	if GameManager:
		GameManager.shrine_tier = min(GameManager.shrine_tier + 1, 5)
		_set_status("Kamikitakuni Shrine upgraded to Tier %d." % GameManager.shrine_tier)

func _max_all_talents() -> void:
	if GameManager:
		for key in GameManager.talent_ranks.keys():
			GameManager.talent_ranks[key] = 5
		_set_status("Maxed out all Faith Web talent tree ranks.")

func _force_gacha_pity() -> void:
	if GameManager:
		GameManager.gacha_pity = 89
		_set_status("Gacha pity set to 89 (Next pull guaranteed 5★ / Holomember)!")

# ---------------------------------------------------------------------------
# Setup Tab 3: Fast Travel & Warps
# ---------------------------------------------------------------------------

func _setup_tab_warps() -> void:
	if btn_warp_shrine:
		btn_warp_shrine.pressed.connect(func(): _warp_to("res://modes_and_maps/story_mode/kamikitakuni_shrine.tscn"))
	if btn_warp_forest:
		btn_warp_forest.pressed.connect(func(): _warp_to("res://modes_and_maps/story_mode/route_01_forest.tscn"))
	if btn_warp_dojo:
		btn_warp_dojo.pressed.connect(func(): _warp_to("res://modes_and_maps/story_mode/gyms/nakiri_dojo_gym.tscn"))
	if btn_warp_blizzard:
		btn_warp_blizzard.pressed.connect(func(): _warp_to("res://modes_and_maps/story_mode/gyms/fubuki_blizzard_gym.tscn"))
	if btn_warp_endless:
		btn_warp_endless.pressed.connect(func(): _warp_to("res://modes_and_maps/endless_mode/endless_arena.tscn"))
	if btn_reload_map:
		btn_reload_map.pressed.connect(_reload_current_map)

func _warp_to(map_path: String) -> void:
	close_menu()
	if SceneManager:
		SceneManager.transition_to_map(map_path, "default", 0.2)
	else:
		get_tree().change_scene_to_file(map_path)

func _reload_current_map() -> void:
	close_menu()
	get_tree().reload_current_scene()

# ---------------------------------------------------------------------------
# Setup Tab 4: Combat & Spawner
# ---------------------------------------------------------------------------

func _setup_tab_combat() -> void:
	if btn_spawn_dummy_idle:
		btn_spawn_dummy_idle.pressed.connect(func(): _spawn_dummy(0))
	if btn_spawn_dummy_atk:
		btn_spawn_dummy_atk.pressed.connect(func(): _spawn_dummy(1))
	if btn_spawn_dummy_move:
		btn_spawn_dummy_move.pressed.connect(func(): _spawn_dummy(2))

	if btn_spawn_chaser:
		btn_spawn_chaser.pressed.connect(func(): _spawn_entity(SCENE_CHASER, "Basic Chaser"))
	if btn_spawn_slime:
		btn_spawn_slime.pressed.connect(func(): _spawn_entity(SCENE_SLIME, "Slime"))
	if btn_spawn_ayame_boss:
		btn_spawn_ayame_boss.pressed.connect(func(): _spawn_entity(SCENE_BOSS_AYAME, "Ayame Boss"))
	if btn_spawn_fubuki_boss:
		btn_spawn_fubuki_boss.pressed.connect(func(): _spawn_entity(SCENE_BOSS_FUBUKI, "Fubuki Boss"))

	if btn_kill_all_enemies:
		btn_kill_all_enemies.pressed.connect(_kill_all_enemies)
	if btn_start_siege:
		btn_start_siege.pressed.connect(_start_siege_raid)

func _spawn_dummy(mode_idx: int) -> void:
	var p := _get_player()
	if not p:
		_set_status("No player found to spawn dummy near.")
		return
	var dummy := SCENE_DUMMY.instantiate()
	var offset := Vector2(randf_range(-100, 100), randf_range(-100, 100))
	if offset.length() < 60:
		offset = offset.normalized() * 75
	dummy.global_position = p.global_position + offset
	if "dummy_mode" in dummy:
		dummy.dummy_mode = mode_idx
	get_tree().current_scene.add_child(dummy)
	_set_status("Spawned Training Dummy.")

func _spawn_entity(scene: PackedScene, entity_label: String) -> void:
	var p := _get_player()
	if not p or not scene:
		return
	var ent := scene.instantiate()
	var offset := Vector2(randf_range(-140, 140), randf_range(-140, 140))
	if offset.length() < 70:
		offset = offset.normalized() * 90
	ent.global_position = p.global_position + offset
	get_tree().current_scene.add_child(ent)
	_set_status("Spawned %s near player." % entity_label)

func _kill_all_enemies() -> void:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if enemy.has_method("take_damage"):
				enemy.take_damage(999999)
			else:
				enemy.queue_free()
			count += 1
	_set_status("Purified %d active enemies." % count)

func _start_siege_raid() -> void:
	for bell in get_tree().get_nodes_in_group("shrine_bell"):
		if is_instance_valid(bell) and bell.has_method("start_siege_defense"):
			bell.start_siege_defense()
			_set_status("Started Sacred Shrine Bell Siege Wave!")
			return
	_set_status("No Shrine Bell found in current scene.")

# ---------------------------------------------------------------------------
# Setup Tab 5: World & Saves
# ---------------------------------------------------------------------------

func _setup_tab_world() -> void:
	if btn_time_dawn:
		btn_time_dawn.pressed.connect(func(): _set_day_period(0))
	if btn_time_noon:
		btn_time_noon.pressed.connect(func(): _set_day_period(1))
	if btn_time_dusk:
		btn_time_dusk.pressed.connect(func(): _set_day_period(2))
	if btn_time_midnight:
		btn_time_midnight.pressed.connect(func(): _set_day_period(3))
	if btn_time_eclipse:
		btn_time_eclipse.pressed.connect(_trigger_eclipse)

	if btn_quick_save:
		btn_quick_save.pressed.connect(_on_quick_save)
	if btn_quick_load:
		btn_quick_load.pressed.connect(_on_quick_load)
	if btn_reset_save:
		btn_reset_save.pressed.connect(_on_reset_save)

func _set_day_period(period_idx: int) -> void:
	if TimeManager:
		TimeManager.set_period(period_idx)
		_set_status("Set time of day to %s." % TimeManager.get_period_name())

func _trigger_eclipse() -> void:
	if TimeManager:
		TimeManager.trigger_eclipse(60.0)
		_set_status("Triggered 60s False Moon Eclipse!")

func _on_quick_save() -> void:
	if SaveManager:
		SaveManager.save_game(1)
		_set_status("Game saved to Slot 1.")

func _on_quick_load() -> void:
	if SaveManager:
		SaveManager.load_game(1)
		_set_status("Game loaded from Slot 1.")

func _on_reset_save() -> void:
	if SaveManager:
		SaveManager.delete_save(1)
		_set_status("Save Slot 1 wiped. Reloading current map...")
		get_tree().create_timer(0.5).timeout.connect(_reload_current_map)

# ---------------------------------------------------------------------------
# Performance & State Synchronisation
# ---------------------------------------------------------------------------

func _sync_state_to_ui() -> void:
	var p := _get_player()
	if p:
		_god_mode_active = p.is_god_mode
		btn_god_mode.text = "🛡️ God Mode: " + ("ON" if _god_mode_active else "OFF")
		btn_god_mode.modulate = Color(0.4, 1.2, 0.4) if _god_mode_active else Color(1, 1, 1)

		if p.has_node("SkillCasterComponent"):
			var caster: SkillCasterComponent = p.get_node("SkillCasterComponent")
			_inf_skills_active = caster.no_cooldowns
			btn_inf_skills.text = "⚡ Instant Skills: " + ("ON" if _inf_skills_active else "OFF")
			btn_inf_skills.modulate = Color(0.4, 1.2, 0.4) if _inf_skills_active else Color(1, 1, 1)

func _update_performance_readout() -> void:
	if not perf_label:
		return
	var fps: int = int(Engine.get_frames_per_second())
	var frame_ms: float = 1000.0 / max(fps, 1)
	var enemies_count: int = get_tree().get_nodes_in_group("enemies").size()
	var total_nodes: int = get_tree().get_node_count()
	var mem_mb: float = float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)

	perf_label.text = "FPS: %d (%.1fms) | Mem: %.1f MB | Enemies: %d | Nodes: %d" % [
		fps, frame_ms, mem_mb, enemies_count, total_nodes
	]
