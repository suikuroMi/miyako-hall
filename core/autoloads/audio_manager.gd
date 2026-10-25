# audio_manager.gd
# Global Autoload singleton managing adaptive BGM crossfading, SFX pooling,
# procedural retro synthesis, and volume control.

extends Node

# ---------------------------------------------------------------------------
# Signals & Constants
# ---------------------------------------------------------------------------
signal bgm_changed(track_name: String)

const SFX_POOL_SIZE: int = 8

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var master_volume: float = 0.8
var bgm_volume: float = 0.7
var sfx_volume: float = 0.85

var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _active_bgm_player: AudioStreamPlayer
var _current_track: String = ""
var _bgm_crossfade_tween: Tween

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Setup dual BGM players for seamless crossfading
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.bus = "Master"
	add_child(_bgm_player_a)

	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.bus = "Master"
	add_child(_bgm_player_b)

	_active_bgm_player = _bgm_player_a

	# Setup SFX Player Pool
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

	# Wire EventBus hooks for reactive audio
	if EventBus:
		EventBus.entity_damaged.connect(func(_ent, _dmg, _crit): play_sfx("hit"))
		EventBus.player_leveled_up.connect(func(_lvl): play_sfx("level_up"))
		EventBus.enemy_purified.connect(func(_data, _pos, _exp): play_sfx("purified"))
		EventBus.currency_changed.connect(func(_amt): play_sfx("coin"))

	if SceneManager:
		SceneManager.transition_started.connect(_on_scene_transition)

# ---------------------------------------------------------------------------
# BGM Management & Crossfading
# ---------------------------------------------------------------------------

func _on_scene_transition(target_map_path: String) -> void:
	if "shrine" in target_map_path:
		play_bgm("shrine_peace")
	elif "forest" in target_map_path:
		play_bgm("forest_journey")
	elif "gym" in target_map_path or "dojo" in target_map_path:
		play_bgm("boss_intensity")
	elif "endless" in target_map_path:
		play_bgm("endless_combat")
	elif "main_menu" in target_map_path:
		play_bgm("title_theme")

## Smoothly crossfades to a new track
func play_bgm(track_name: String, fade_duration: float = 1.0) -> void:
	if _current_track == track_name:
		return
	_current_track = track_name
	bgm_changed.emit(track_name)

	# Prepare next player
	var outgoing_player: AudioStreamPlayer = _active_bgm_player
	var incoming_player: AudioStreamPlayer = _bgm_player_b if outgoing_player == _bgm_player_a else _bgm_player_a

	# Check for physical audio file in project
	var stream_path := "res://assets/audio/bgm/%s.ogg" % track_name
	if ResourceLoader.exists(stream_path):
		incoming_player.stream = load(stream_path)
	else:
		# Procedural ambient generator fallback
		incoming_player.stream = _generate_ambient_tone(track_name)

	incoming_player.volume_db = linear_to_db(0.001)
	incoming_player.play()

	if _bgm_crossfade_tween and _bgm_crossfade_tween.is_valid():
		_bgm_crossfade_tween.kill()

	_bgm_crossfade_tween = create_tween()
	var target_db := linear_to_db(master_volume * bgm_volume)

	_bgm_crossfade_tween.parallel().tween_property(incoming_player, "volume_db", target_db, fade_duration)
	_bgm_crossfade_tween.parallel().tween_property(outgoing_player, "volume_db", -80.0, fade_duration)
	_bgm_crossfade_tween.finished.connect(func():
		outgoing_player.stop()
		_active_bgm_player = incoming_player
	)

# ---------------------------------------------------------------------------
# SFX Pooling & Synthesis
# ---------------------------------------------------------------------------

## Plays a pooled SFX by name
func play_sfx(sfx_name: String, pitch_variance: float = 0.08) -> void:
	var player: AudioStreamPlayer = _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % SFX_POOL_SIZE

	var file_path := "res://assets/audio/sfx/%s.wav" % sfx_name
	if ResourceLoader.exists(file_path):
		player.stream = load(file_path)
	else:
		player.stream = _synthesize_sfx(sfx_name)

	player.volume_db = linear_to_db(master_volume * sfx_volume)
	player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.play()

# ---------------------------------------------------------------------------
# Volume Configuration
# ---------------------------------------------------------------------------

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	if _active_bgm_player:
		_active_bgm_player.volume_db = linear_to_db(master_volume * bgm_volume)

func set_bgm_volume(value: float) -> void:
	bgm_volume = clamp(value, 0.0, 1.0)
	if _active_bgm_player:
		_active_bgm_player.volume_db = linear_to_db(master_volume * bgm_volume)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)

# ---------------------------------------------------------------------------
# Procedural Audio Synthesizer (Zero-Asset Fallback)
# ---------------------------------------------------------------------------

func _synthesize_sfx(sfx_type: String) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.15
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate

	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)

	var freq: float = 440.0
	match sfx_type:
		"hit":
			duration = 0.12
			freq = 180.0
		"dash":
			duration = 0.16
			freq = 320.0
		"level_up":
			duration = 0.28
			freq = 660.0
		"coin":
			duration = 0.18
			freq = 880.0
		"purified":
			duration = 0.35
			freq = 523.25 # C5 chord

	total_samples = int(sample_rate * duration)
	data.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var envelope: float = 1.0 - (float(i) / float(total_samples))
		var wave: float = sin(t * freq * TAU)
		if sfx_type == "dash":
			# Noise whoosh
			wave = (randf() * 2.0 - 1.0) * 0.7
		var sample_val: int = int(clamp((wave * envelope * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		data[i] = sample_val

	wav.data = data
	return wav

func _generate_ambient_tone(_theme: String) -> AudioStreamWAV:
	var sample_rate: int = 11025
	var duration: float = 2.0
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD

	var total_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var wave: float = sin(t * 220.0 * TAU) * 0.2 + sin(t * 330.0 * TAU) * 0.15
		var sample_val: int = int(clamp((wave * 0.4 + 0.5) * 255.0, 0.0, 255.0))
		data[i] = sample_val

	wav.data = data
	return wav
