# nakiri_dojo_gym.gd
# Controller for the first Holomember Boss Gym (Nakiri Ayame).

extends Node2D

@onready var boss: Node2D = get_node_or_null("BossNakiriAyame")
@onready var boss_ui: CanvasLayer = $BossUI
@onready var boss_hp_bar: ProgressBar = $BossUI/VBox/ProgressBar
@onready var poise_bar: ProgressBar = $BossUI/VBox/PoiseBar
@onready var boss_name_label: Label = $BossUI/VBox/BossName
@onready var victory_banner: Label = $BossUI/VictoryBanner
@onready var return_gate: Area2D = $GateToForest
@onready var brazier_left: SpiritBrazier = get_node_or_null("BrazierLeft") as SpiritBrazier
@onready var brazier_right: SpiritBrazier = get_node_or_null("BrazierRight") as SpiritBrazier

var _braziers_lit: int = 0

func _ready() -> void:
	victory_banner.visible = false
	if boss:
		boss.boss_hp_changed.connect(_on_boss_hp_changed)
		boss.purified.connect(_on_boss_purified)
		boss.phase_changed.connect(_on_boss_phase_changed)
		if "poise_changed" in boss:
			boss.poise_changed.connect(_on_boss_poise_changed)
			boss.staggered.connect(_on_boss_staggered)
			boss.recovered.connect(_on_boss_recovered)

	var is_cleared: bool = GameManager and GameManager.get_story_flag("gym_cleared_nakiri_ayame")

	if is_cleared:
		if brazier_left: brazier_left.is_lit = true; brazier_left._update_visuals()
		if brazier_right: brazier_right.is_lit = true; brazier_right._update_visuals()
	else:
		if brazier_left: brazier_left.lit.connect(_on_brazier_lit)
		if brazier_right: brazier_right.lit.connect(_on_brazier_lit)
		# Defer prompt slightly so HUD has fully initialized
		call_deferred("_trigger_intro_hint")

func _trigger_intro_hint() -> void:
	var hint_lines := [
		{
			"speaker": "⛩️ Sacred Dojo Ward",
			"text": "An oppressive flame barrier shields Nakiri Ayame. Ignite both Spirit Braziers to dispel the ward and challenge the Gym Leader!"
		}
	]
	if EventBus:
		EventBus.dialogue_started.emit(hint_lines)

func _on_brazier_lit(_id: String) -> void:
	_braziers_lit += 1
	if _braziers_lit >= 2:
		if boss and boss.has_method("trigger_cinematic_intro"):
			boss.trigger_cinematic_intro()
		if AudioManager:
			AudioManager.play_sfx("purified")
		var intro_lines := [
			{
				"speaker": "⛩️ Sacred Dojo Ward",
				"text": "The Spirit Braziers ignite in radiant unison! The flame barrier shatters!"
			},
			{
				"speaker": "🔥 Corrupted Nakiri Ayame",
				"text": "...Who goes there? The spiritual flames... they burn within my soul... I can't hold back!"
			},
			{
				"speaker": "Ookami Mio",
				"text": "Ayame! Hang on, I will purify this dark stigmata and bring you back!"
			},
			{
				"speaker": "🔥 Corrupted Nakiri Ayame",
				"text": "Draw your weapon! Let us see if your spirit is strong enough to pierce my blades!"
			}
		]
		if EventBus:
			EventBus.dialogue_started.emit(intro_lines)

func _on_boss_hp_changed(current: float, max_hp: float) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = current

func _on_boss_phase_changed(_phase: int) -> void:
	if boss_name_label:
		boss_name_label.text = "🔥 ENRAGED NAKIRI AYAME (PHASE 2) 🔥"
		boss_name_label.modulate = Color(1.0, 0.3, 0.3, 1.0)

func _on_boss_poise_changed(current: float, max_p: float) -> void:
	if poise_bar:
		poise_bar.max_value = max_p
		poise_bar.value = current

func _on_boss_staggered(_dur: float) -> void:
	if boss_name_label:
		boss_name_label.text = "💫 STAGGER BREAK! VULNERABLE! (1.5x DMG) 💫"
		boss_name_label.modulate = Color(1.0, 0.85, 0.2, 1.0)

func _on_boss_recovered() -> void:
	if boss_name_label:
		var phase_text := "🔥 ENRAGED NAKIRI AYAME (PHASE 2) 🔥" if (boss and "current_phase" in boss and boss.current_phase == 2) else "⛩️ CORRUPTED NAKIRI AYAME — DEMON SHRINE MAIDEN"
		boss_name_label.text = phase_text
		boss_name_label.modulate = Color(1.0, 0.3, 0.3, 1.0) if (boss and "current_phase" in boss and boss.current_phase == 2) else Color.WHITE

func _on_boss_purified() -> void:
	if victory_banner:
		victory_banner.visible = true
	if boss_hp_bar:
		boss_hp_bar.visible = false
	if poise_bar:
		poise_bar.visible = false
	if boss_name_label:
		boss_name_label.text = "✨ SPIRIT PURIFIED — NAKIRI AYAME UNLOCKED ✨"
		boss_name_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	if return_gate:
		return_gate.visible = true

	var outro_lines := [
		{
			"speaker": "Nakiri Ayame",
			"text": "Mio...? The darkness... it has completely vanished. My mind is clear again."
		},
		{
			"speaker": "Ookami Mio",
			"text": "Welcome back, Ayame! I'm so glad you're safe."
		},
		{
			"speaker": "Nakiri Ayame",
			"text": "I owe you my life. From this day forth, my dual blades are yours to command in battle!"
		},
		{
			"speaker": "🎉 Holomember Unlocked",
			"text": "Nakiri Ayame has joined your active roster! Press [C] anytime to swap to her!"
		}
	]
	if EventBus:
		EventBus.dialogue_started.emit(outro_lines)
