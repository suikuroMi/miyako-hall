extends ProgressBar

var _player: Node

func _ready():
	_player = get_tree().root.find_child("Player", true, false)
	if _player and _player.has_signal("health_changed"):
		_player.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(_player.health, _player.max_health)

func _on_player_health_changed(current_health: int, max_health: int):
	max_value = max_health
	value = current_health
