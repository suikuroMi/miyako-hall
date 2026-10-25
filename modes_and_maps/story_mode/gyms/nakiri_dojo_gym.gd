# nakiri_dojo_gym.gd
# Controller for the first Holomember Boss Gym (Nakiri Ayame).

extends Node2D

@onready var boss: Node2D = get_node_or_null("BossNakiriAyame")
@onready var boss_ui: CanvasLayer = $BossUI
@onready var boss_hp_bar: ProgressBar = $BossUI/VBox/ProgressBar
@onready var boss_name_label: Label = $BossUI/VBox/BossName
@onready var victory_banner: Label = $BossUI/VictoryBanner
@onready var return_gate: Area2D = $GateToForest

func _ready() -> void:
	victory_banner.visible = false
	if boss:
		boss.boss_hp_changed.connect(_on_boss_hp_changed)
		boss.purified.connect(_on_boss_purified)
		boss.phase_changed.connect(_on_boss_phase_changed)

	# Trigger Pre-Fight Dialogue if not yet cleared
	if GameManager and not GameManager.get_story_flag("gym_cleared_nakiri_ayame"):
		var intro_lines := [
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
		# Defer slightly so HUD has fully initialized
		call_deferred("_trigger_intro_dialogue", intro_lines)

func _trigger_intro_dialogue(lines: Array) -> void:
	if EventBus:
		EventBus.dialogue_started.emit(lines)

func _on_boss_hp_changed(current: float, max_hp: float) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = current

func _on_boss_phase_changed(_phase: int) -> void:
	if boss_name_label:
		boss_name_label.text = "🔥 ENRAGED NAKIRI AYAME (PHASE 2) 🔥"
		boss_name_label.modulate = Color(1.0, 0.3, 0.3, 1.0)

func _on_boss_purified() -> void:
	if victory_banner:
		victory_banner.visible = true
	if boss_hp_bar:
		boss_hp_bar.visible = false
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
