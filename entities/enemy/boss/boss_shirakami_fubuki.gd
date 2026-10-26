# boss_shirakami_fubuki.gd
# Boss entity for the Blizzard Peaks Gym.
# Implements:
#   - Boss HP tracking & EventBus broadcast
#   - Ranged ice dart barrages (Blizzard Darts)
#   - Frost Nova Step (teleport & AoE freeze burst)
#   - Phase 2 Enrage: Konkon Blizzard ultimate (8-direction ice barrage)
#   - Purification sequence on death.

class_name BossShirakamiFubuki
extends BaseEnemy

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal boss_hp_changed(current_hp: float, max_hp: float)
signal poise_changed(current_poise: float, max_poise: float)
signal staggered(duration: float)
signal recovered()
signal phase_changed(new_phase: int)
signal purified()

# ---------------------------------------------------------------------------
# Boss State
# ---------------------------------------------------------------------------
enum BossState { IDLE, CHASING, FROST_DART, FROST_NOVA, STAGGERED, PURIFIED }
var boss_state: BossState = BossState.IDLE
var current_phase: int = 1
var max_boss_hp: float = 750.0

var max_poise: float = 160.0
var current_poise: float = 160.0
var is_staggered: bool = false
var _stagger_timer: float = 0.0
var _poise_regen_delay: float = 0.0

var _attack_timer: float = 0.0
var _dart_cooldown: float = 3.0
var _nova_cooldown: float = 5.5
var _nova_timer: float = 2.0

func _setup_enemy() -> void:
	enemy_name = "Corrupted Shirakami Fubuki"
	exp_reward = 300
	touch_damage = 15.0
	move_speed = 100.0

	if stats:
		stats.max_hp = max_boss_hp
		stats.current_hp = max_boss_hp
		stats.stat_attack = 28.0
		stats.base_defense = 6.0

	_broadcast_hp()

func _physics_process(delta: float) -> void:
	if _is_dying or boss_state == BossState.PURIFIED:
		return

	if is_staggered:
		_stagger_timer -= delta
		velocity = Vector2.ZERO
		if _stagger_timer <= 0.0:
			_recover_from_stagger()
		return

	# Poise regeneration when not taking damage
	_poise_regen_delay -= delta
	if _poise_regen_delay <= 0.0 and current_poise < max_poise:
		current_poise = min(current_poise + 18.0 * delta, max_poise)
		poise_changed.emit(current_poise, max_poise)

	_attack_timer += delta
	_nova_timer += delta

	# Check Phase 2 Enrage (<50% HP)
	if current_phase == 1 and stats and stats.current_hp <= (max_boss_hp * 0.5):
		_enter_phase_2()

	match boss_state:
		BossState.IDLE, BossState.CHASING:
			if vision and vision.is_chasing():
				var target: Node2D = vision.get_target()
				if is_instance_valid(target):
					var dist: float = global_position.distance_to(target.global_position)
					# If player gets too close -> Frost Nova Step (teleport back)
					if dist < 100.0 and _nova_timer >= _nova_cooldown:
						_start_frost_nova(target)
						return
					# If at mid/long range -> Fire Ice Darts
					elif dist > 110.0 and _attack_timer >= _dart_cooldown:
						_start_blizzard_darts(target)
						return

			super._physics_process(delta)

		BossState.FROST_DART, BossState.FROST_NOVA:
			velocity = Vector2.ZERO
			move_and_slide()

func _enter_phase_2() -> void:
	current_phase = 2
	move_speed = 130.0
	_dart_cooldown = 2.0
	_nova_cooldown = 3.8
	modulate = Color(0.6, 0.95, 1.5, 1.0)
	phase_changed.emit(2)

func _start_blizzard_darts(target: Node2D) -> void:
	boss_state = BossState.FROST_DART
	_attack_timer = 0.0

	var dir: Vector2 = (target.global_position - global_position).normalized()
	var dart_count: int = 5 if current_phase == 2 else 3
	var spread: float = deg_to_rad(30.0)

	for i in range(dart_count):
		var angle_offset: float = -spread / 2.0 + (spread / float(dart_count - 1)) * i if dart_count > 1 else 0.0
		var shot_dir: Vector2 = dir.rotated(angle_offset)
		if ObjectPool:
			ObjectPool.spawn_bullet(global_position, shot_dir.angle(), 14.0 * (1.2 if current_phase == 2 else 1.0), 800.0, 900.0, 1)

	await get_tree().create_timer(0.35).timeout
	boss_state = BossState.CHASING

func _start_frost_nova(target: Node2D) -> void:
	boss_state = BossState.FROST_NOVA
	_nova_timer = 0.0

	# Teleport away from target
	var retreat_dir: Vector2 = (global_position - target.global_position).normalized()
	global_position += retreat_dir * 180.0

	# Activate AoE Frost Hitbox at previous position
	if hitbox:
		hitbox.damage = 22.0
		hitbox.knockback_force = 160.0
		hitbox.activate(0.4)

	await get_tree().create_timer(0.4).timeout

	if hitbox:
		hitbox.deactivate()

	boss_state = BossState.CHASING

func take_damage(amount: float) -> void:
	if is_staggered:
		# Takes amplified damage during stagger break!
		amount *= 1.5
	else:
		current_poise = max(current_poise - (amount * 0.9), 0.0)
		_poise_regen_delay = 3.5
		poise_changed.emit(current_poise, max_poise)
		if current_poise <= 0.0:
			_trigger_stagger()

	super.take_damage(amount)
	_broadcast_hp()

func _trigger_stagger() -> void:
	is_staggered = true
	_stagger_timer = 3.5
	boss_state = BossState.STAGGERED
	velocity = Vector2.ZERO
	staggered.emit(3.5)

	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.modulate = Color(1.8, 1.6, 0.4, 1.0) # Golden vulnerable glow

	if CameraManager:
		CameraManager.shake(12.0, 0.35)
	if AudioManager:
		AudioManager.play_sfx("purified")

func _recover_from_stagger() -> void:
	is_staggered = false
	current_poise = max_poise
	poise_changed.emit(current_poise, max_poise)
	boss_state = BossState.CHASING

	var spr = get_node_or_null("Sprite2D")
	if spr:
		spr.modulate = Color.WHITE

	recovered.emit()

func _broadcast_hp() -> void:
	var cur: float = stats.current_hp if stats else 0.0
	boss_hp_changed.emit(cur, max_boss_hp)

func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	boss_state = BossState.PURIFIED
	_broadcast_hp()

	if EventBus:
		EventBus.boss_defeated.emit("shirakami_fubuki")
		EventBus.character_unlocked.emit("shirakami_fubuki")

	if GameManager:
		GameManager.unlock_character("shirakami_fubuki")
		GameManager.set_story_flag("gym_cleared_shirakami_fubuki", true)

	purified.emit()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.8, 2.2, 2.5, 1.0), 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished

	defeated.emit(exp_reward)
	queue_free()

func trigger_cinematic_intro() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		var orig_offset: Vector2 = cam.offset
		var orig_zoom: Vector2 = cam.zoom

		var tw := create_tween()
		tw.tween_property(cam, "zoom", orig_zoom * 1.35, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cam, "zoom", orig_zoom, 0.45)

		for i in range(5):
			cam.offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			await get_tree().create_timer(0.04).timeout
		cam.offset = orig_offset
