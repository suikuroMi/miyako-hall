# health_bar.gd
# ProgressBar that displays the player's current HP.
#
# Decoupled from the Player node via EventBus — no more find_child("Player").
# EventBus.player_hp_changed is emitted by StatsComponent whenever HP changes.
#
# Setup:
#   1. Attach this script to a ProgressBar node in your HUD scene.
#   2. No manual connections needed — EventBus wires everything in _ready().

extends ProgressBar

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Listen for HP updates from anywhere in the game
	EventBus.player_hp_changed.connect(_on_player_hp_changed)

	# Try to read initial HP from the Player node if it's already in the tree
	# (handles cases where the HUD loads after the player scene)
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player_stats: StatsComponent = players[0].get_node_or_null("StatsComponent")
		if player_stats:
			_on_player_hp_changed(player_stats.current_hp, player_stats.max_hp)

# ---------------------------------------------------------------------------
# EventBus callbacks
# ---------------------------------------------------------------------------

func _on_player_hp_changed(current_hp: float, max_hp: float) -> void:
	max_value = max_hp
	value     = current_hp
