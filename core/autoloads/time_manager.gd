# time_manager.gd
# Global Autoload singleton managing the Day/Night and False Moon Eclipse cycle.
# Modulates global ambient lighting and buffs enemy difficulty and rewards during Eclipse twilight.

extends Node

# ---------------------------------------------------------------------------
# Enums & Signals
# ---------------------------------------------------------------------------

enum TimePeriod {
	DAWN,
	DAY,
	DUSK,
	NIGHT,
	FALSE_MOON_ECLIPSE
}

signal period_changed(new_period: TimePeriod, period_name: String)
signal eclipse_started()
signal eclipse_ended()

const PERIOD_COLORS: Dictionary = {
	TimePeriod.DAWN: Color(1.05, 0.92, 0.82),
	TimePeriod.DAY: Color(1.0, 1.0, 1.0),
	TimePeriod.DUSK: Color(0.96, 0.72, 0.82),
	TimePeriod.NIGHT: Color(0.48, 0.52, 0.78),
	TimePeriod.FALSE_MOON_ECLIPSE: Color(0.88, 0.30, 0.46)
}

const PERIOD_NAMES: Dictionary = {
	TimePeriod.DAWN: "Dawn",
	TimePeriod.DAY: "Day",
	TimePeriod.DUSK: "Dusk",
	TimePeriod.NIGHT: "Night",
	TimePeriod.FALSE_MOON_ECLIPSE: "False Moon Eclipse"
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var current_period: TimePeriod = TimePeriod.DAY
var is_eclipse: bool = false
var time_speed: float = 1.0
var _period_timer: float = 90.0 # 90s per daylight period
var _eclipse_timer: float = 0.0

var _modulate: CanvasModulate = null
var _tween: Tween = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Register scene transition hook to rebind CanvasModulate
	if SceneManager:
		SceneManager.transition_completed.connect(_on_scene_changed)

	_ensure_canvas_modulate()
	_apply_period_color(false)

func _process(delta: float) -> void:
	if is_eclipse:
		_eclipse_timer -= delta
		if _eclipse_timer <= 0.0:
			end_eclipse()
		return

	_period_timer -= delta * time_speed
	if _period_timer <= 0.0:
		_period_timer = 90.0
		advance_time_period()

func _unhandled_input(event: InputEvent) -> void:
	# Hotkey 'T' to advance time period / toggle eclipse
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T:
			if is_eclipse:
				end_eclipse()
			elif current_period == TimePeriod.NIGHT:
				trigger_eclipse(45.0)
			else:
				advance_time_period()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func advance_time_period() -> void:
	if is_eclipse:
		end_eclipse()
		return

	match current_period:
		TimePeriod.DAWN:
			set_period(TimePeriod.DAY)
		TimePeriod.DAY:
			set_period(TimePeriod.DUSK)
		TimePeriod.DUSK:
			set_period(TimePeriod.NIGHT)
		TimePeriod.NIGHT:
			set_period(TimePeriod.DAWN)

func set_period(new_period: TimePeriod) -> void:
	current_period = new_period
	is_eclipse = (new_period == TimePeriod.FALSE_MOON_ECLIPSE)
	_apply_period_color(true)
	period_changed.emit(current_period, PERIOD_NAMES[current_period])

func trigger_eclipse(duration: float = 60.0) -> void:
	is_eclipse = true
	_eclipse_timer = duration
	current_period = TimePeriod.FALSE_MOON_ECLIPSE
	_apply_period_color(true)
	eclipse_started.emit()
	period_changed.emit(current_period, "False Moon Eclipse")

	if AudioManager:
		AudioManager.play_sfx("hit")

func end_eclipse() -> void:
	if not is_eclipse:
		return
	is_eclipse = false
	current_period = TimePeriod.NIGHT
	_apply_period_color(true)
	eclipse_ended.emit()
	period_changed.emit(current_period, "Night")

func get_ambient_color() -> Color:
	return PERIOD_COLORS[current_period]

func get_period_name() -> String:
	return PERIOD_NAMES[current_period]

func get_enemy_speed_multiplier() -> float:
	return 1.15 if is_eclipse else 1.0

func get_enemy_damage_multiplier() -> float:
	return 1.10 if is_eclipse else 1.0

func get_exp_multiplier() -> float:
	return 1.50 if is_eclipse else 1.0

func get_coin_multiplier() -> float:
	return 2.0 if is_eclipse else 1.0

# ---------------------------------------------------------------------------
# Visual Application
# ---------------------------------------------------------------------------

func _on_scene_changed(_target_map_path: String) -> void:
	_ensure_canvas_modulate()
	_apply_period_color(false)

func _ensure_canvas_modulate() -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	# Don't darken the main menu
	if "main_menu" in tree.current_scene.scene_file_path:
		if is_instance_valid(_modulate):
			_modulate.color = Color.WHITE
		return

	var existing = tree.current_scene.find_child("TimeCanvasModulate", true, false)
	if is_instance_valid(existing) and existing is CanvasModulate:
		_modulate = existing
	else:
		_modulate = CanvasModulate.new()
		_modulate.name = "TimeCanvasModulate"
		tree.current_scene.add_child(_modulate)

func _apply_period_color(smooth: bool) -> void:
	_ensure_canvas_modulate()
	if not is_instance_valid(_modulate):
		return

	var target_col: Color = PERIOD_COLORS[current_period]

	if _tween and _tween.is_valid():
		_tween.kill()

	if smooth:
		_tween = create_tween()
		_tween.tween_property(_modulate, "color", target_col, 2.5).set_trans(Tween.TRANS_SINE)
	else:
		_modulate.color = target_col
