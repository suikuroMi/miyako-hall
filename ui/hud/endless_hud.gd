# endless_hud.gd
# HUD overlay displayed during Endless Mode to track active Wave, Survival Time, and Kills.

extends PanelContainer

@onready var _stats_label: Label = $MarginContainer/StatsLabel

func _ready() -> void:
	if EventBus:
		EventBus.endless_stats_updated.connect(_on_stats_updated)
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.wave_completed.connect(_on_wave_completed)
	
	_update_display(0.0, 1, 0)

func _update_display(time_sec: float, wave: int, kills: int) -> void:
	if not _stats_label:
		return
	var mins: int = int(time_sec) / 60
	var secs: int = int(time_sec) % 60
	_stats_label.text = "⚔️ WAVE %d   |   ⏱️ %02d:%02d   |   💀 KILLS: %d" % [wave, mins, secs, kills]

func _on_stats_updated(time_sec: float, wave: int, kills: int) -> void:
	_update_display(time_sec, wave, kills)

func _on_wave_started(wave: int) -> void:
	modulate = Color(1.3, 1.2, 0.4) # Flash gold on wave start
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.6)

func _on_wave_completed(wave: int) -> void:
	modulate = Color(0.4, 1.3, 0.6) # Flash green on wave cleared
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.6)
