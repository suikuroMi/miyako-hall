# fubuki_blizzard_gym.gd
# Controller for the second Holomember Boss Gym (Shirakami Fubuki).

extends Node2D

@onready var boss: Node2D = get_node_or_null("BossShirakamiFubuki")
@onready var boss_ui: CanvasLayer = $BossUI
@onready var boss_hp_bar: ProgressBar = $BossUI/VBox/ProgressBar
@onready var boss_name_label: Label = $BossUI/VBox/BossName
@onready var victory_banner: Label = $BossUI/VictoryBanner
@onready var return_gate: Area2D = $GateToShrine

func _ready() -> void:
	victory_banner.visible = false
	if boss:
		boss.boss_hp_changed.connect(_on_boss_hp_changed)
		boss.purified.connect(_on_boss_purified)
		boss.phase_changed.connect(_on_boss_phase_changed)

	if GameManager and not GameManager.get_story_flag("gym_cleared_shirakami_fubuki"):
		var intro_lines := [
			{
				"speaker": "❄️ Corrupted Shirakami Fubuki",
				"text": "Konkon... The blizzard chills my senses... Who steps upon the sacred summit?"
			},
			{
				"speaker": "Ookami Mio",
				"text": "Fubuki! It's me, Mio! Snap out of the icy corruption!"
			},
			{
				"speaker": "❄️ Corrupted Shirakami Fubuki",
				"text": "Mio...? No... The frost consumes everything! Defend yourself!"
			}
		]
		call_deferred("_trigger_intro_dialogue", intro_lines)

func _trigger_intro_dialogue(lines: Array) -> void:
	if boss and boss.has_method("trigger_cinematic_intro"):
		boss.trigger_cinematic_intro()
	if EventBus:
		EventBus.dialogue_started.emit(lines)

func _on_boss_hp_changed(current: float, max_hp: float) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = current

func _on_boss_phase_changed(_phase: int) -> void:
	if boss_name_label:
		boss_name_label.text = "❄️ BLIZZARD KAMI FUBUKI (PHASE 2) ❄️"
		boss_name_label.modulate = Color(0.4, 0.9, 1.2, 1.0)

func _on_boss_purified() -> void:
	if victory_banner:
		victory_banner.visible = true
	if boss_hp_bar:
		boss_hp_bar.visible = false
	if boss_name_label:
		boss_name_label.text = "✨ SPIRIT PURIFIED — FUBUKI's BLESSING AWAKENED ✨"
		boss_name_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	if return_gate:
		return_gate.visible = true

	var outro_lines := [
		{
			"speaker": "Shirakami Fubuki",
			"text": "Mio... The freezing mist has cleared. Thank goodness you came for me!"
		},
		{
			"speaker": "Ookami Mio",
			"text": "FubuMio will never be broken by spiritual corruption! Let's save the rest of our friends together!"
		},
		{
			"speaker": "Shirakami Fubuki",
			"text": "Yes! My blizzard darts and frost arrows are with you all the way!"
		},
		{
			"speaker": "🎉 Holomember Bond Awakened",
			"text": "Shirakami Fubuki's Faith Resonance has deepened! Press [1] / [2] anytime to swap between FubuMio!"
		}
	]
	if EventBus:
		EventBus.dialogue_started.emit(outro_lines)
