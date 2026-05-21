extends VBoxContainer

var _player: Node

@onready var _level_exp_label: Label = $LevelExpLabel
@onready var _stats_label: Label = $StatsLabel
@onready var _hint_label: Label = $HintLabel

func _ready():
	_player = get_tree().root.find_child("Player", true, false)
	_hint_label.text = "H: -HP   J: +HP   K: +EXP"

	if not _player:
		return

	if _player.has_signal("exp_changed"):
		_player.exp_changed.connect(_on_exp_changed)
	if _player.has_signal("stats_changed"):
		_player.stats_changed.connect(_on_stats_changed)

	_on_exp_changed(_player.current_exp, _player.exp_to_next_level, _player.level)
	_on_stats_changed(_player.stat_damage, _player.stat_speed, _player.stat_intelligence, _player.max_health)

func _on_exp_changed(current_exp: int, exp_to_next_level: int, level: int):
	_level_exp_label.text = "LVL %d   EXP %d / %d" % [level, current_exp, exp_to_next_level]

func _on_stats_changed(damage: int, speed: int, intelligence: int, max_health: int):
	_stats_label.text = "DMG %d   SPD %d   INT %d   HP %d" % [damage, speed, intelligence, max_health]
