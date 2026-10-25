# player_stats_hud.gd
# VBoxContainer that displays player HP, EXP, Level, and combat stats in the HUD.
# Decoupled via EventBus.

extends VBoxContainer

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var _level_exp_label: Label = get_node_or_null("LevelExpLabel")
@onready var _stats_label: Label = get_node_or_null("StatsLabel")
@onready var _hint_label: Label = get_node_or_null("HintLabel")

# Fallback label nodes in case scene uses different naming
@onready var label_hp: Label = get_node_or_null("LabelHP")
@onready var label_exp: Label = get_node_or_null("LabelEXP")
@onready var label_level: Label = get_node_or_null("LabelLevel")

var _current_level: int = 1
var _current_exp: int = 0
var _exp_to_next: int = 100
var _hp: float = 100.0
var _max_hp: float = 100.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if _hint_label:
		_hint_label.text = "Space/Shift: Dash  |  Q/E/R: Skills  |  R-Click: Attack"

	# Connect EventBus signals
	if EventBus:
		EventBus.player_hp_changed.connect(_on_player_hp_changed)
		EventBus.player_exp_changed.connect(_on_player_exp_changed)
		EventBus.player_stats_changed.connect(_on_player_stats_changed)

	# Fetch initial values if player already exists
	_refresh_from_player()

func _refresh_from_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		var s: StatsComponent = p.get_node_or_null("StatsComponent")
		if s:
			_hp = s.current_hp
			_max_hp = s.max_hp
			_current_exp = s.current_exp
			_exp_to_next = s.exp_to_next_level
			_current_level = s.level
			_update_labels(s)
			return

	_update_labels(null)

# ---------------------------------------------------------------------------
# EventBus callbacks
# ---------------------------------------------------------------------------

func _on_player_hp_changed(current_hp: float, max_hp: float) -> void:
	_hp = current_hp
	_max_hp = max_hp
	_update_labels()

func _on_player_exp_changed(current_exp: int, exp_to_next: int, level: int) -> void:
	_current_exp = current_exp
	_exp_to_next = exp_to_next
	_current_level = level
	_update_labels()

func _on_player_stats_changed() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var s: StatsComponent = players[0].get_node_or_null("StatsComponent")
		if s:
			_update_labels(s)

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func _update_labels(stats_comp: StatsComponent = null) -> void:
	if _level_exp_label:
		_level_exp_label.text = "LVL %d   EXP %d / %d" % [_current_level, _current_exp, _exp_to_next]

	if _stats_label:
		if stats_comp == null:
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				stats_comp = players[0].get_node_or_null("StatsComponent")

		if stats_comp:
			_stats_label.text = "ATK %.0f   SPD %.0f   INT %.0f   HP %d/%d" % [
				stats_comp.stat_attack,
				stats_comp.stat_speed,
				stats_comp.stat_intelligence,
				int(_hp),
				int(_max_hp)
			]
		else:
			_stats_label.text = "HP %d / %d" % [int(_hp), int(_max_hp)]

	# Support separate labels if present
	if label_hp:
		label_hp.text = "HP: %d / %d" % [int(_hp), int(_max_hp)]
	if label_exp:
		label_exp.text = "EXP: %d / %d" % [_current_exp, _exp_to_next]
	if label_level:
		label_level.text = "LV: %d" % _current_level
