# boss_nakiri_ayame.gd
# Boss entity for the Haunted Dojo Gym.
# Implements:
#   - Boss HP tracking & EventBus broadcast
#   - Dual Blade Whirlwind (AoE) & Flash Step Dash (teleport slash)
#   - Phase 2 enrage below 50% HP
#   - Purification sequence on death: screen flash, unlock Nakiri Ayame, spawn return gate.

class_name BossNakiriAyame
extends BaseEnemy

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal boss_hp_changed(current_hp: float, max_hp: float)
signal phase_changed(new_phase: int)
signal purified()

# ---------------------------------------------------------------------------
# Boss State
# ---------------------------------------------------------------------------
enum BossState { IDLE, CHASING, WHIRLWIND, FLASH_STEP, PURIFIED }
var boss_state: BossState = BossState.IDLE
var current_phase: int = 1
var max_boss_hp: float = 650.0

var _attack_timer: float = 0.0
var _whirlwind_cooldown: float = 3.5
var _flash_step_cooldown: float = 5.0
var _flash_timer: float = 2.0

func _setup_enemy() -> void:
	enemy_name = "Corrupted Nakiri Ayame"
	exp_reward = 250
	touch_damage = 18.0
	move_speed = 110.0

	if stats:
		stats.max_hp = max_boss_hp
		stats.current_hp = max_boss_hp
		stats.stat_attack = 30.0
		stats.base_defense = 8.0

	_broadcast_hp()

func _physics_process(delta: float) -> void:
	if _is_dying or boss_state == BossState.PURIFIED:
		return

	_attack_timer += delta
	_flash_timer += delta

	# Check Phase 2 Enrage (<50% HP)
	if current_phase == 1 and stats and stats.current_hp <= (max_boss_hp * 0.5):
		_enter_phase_2()

	match boss_state:
		BossState.IDLE, BossState.CHASING:
			if vision and vision.is_chasing():
				var target: Node2D = vision.get_target()
				if is_instance_valid(target):
					var dist: float = global_position.distance_to(target.global_position)
					if dist < 80.0 and _attack_timer >= _whirlwind_cooldown:
						_start_whirlwind(target)
						return
					elif dist > 140.0 and _flash_timer >= _flash_step_cooldown:
						_start_flash_step(target)
						return

			super._physics_process(delta)

		BossState.WHIRLWIND:
			velocity = Vector2.ZERO
			move_and_slide()

		BossState.FLASH_STEP:
			move_and_slide()

func _enter_phase_2() -> void:
	current_phase = 2
	move_speed = 145.0
	_whirlwind_cooldown = 2.2
	_flash_step_cooldown = 3.0
	modulate = Color(1.4, 0.4, 0.4, 1.0)
	phase_changed.emit(2)

func _start_whirlwind(_target: Node2D) -> void:
	boss_state = BossState.WHIRLWIND
	_attack_timer = 0.0

	if hitbox:
		hitbox.damage = 25.0 * (1.3 if current_phase == 2 else 1.0)
		hitbox.knockback_force = 220.0
		hitbox.activate(0.6)

	var tween := create_tween()
	tween.tween_property(self, "rotation", rotation + TAU * 2.0, 0.6)
	await tween.finished
	rotation = 0.0

	if hitbox:
		hitbox.deactivate()

	boss_state = BossState.CHASING

func _start_flash_step(target: Node2D) -> void:
	boss_state = BossState.FLASH_STEP
	_flash_timer = 0.0

	var dir := (target.global_position - global_position).normalized()
	velocity = dir * 450.0

	if hitbox:
		hitbox.damage = 20.0
		hitbox.knockback_force = 120.0
		hitbox.activate(0.3)

	await get_tree().create_timer(0.3).timeout

	if hitbox:
		hitbox.deactivate()

	velocity = Vector2.ZERO
	boss_state = BossState.CHASING

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	_broadcast_hp()

func _broadcast_hp() -> void:
	var cur = stats.current_hp if stats else 0.0
	boss_hp_changed.emit(cur, max_boss_hp)

func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	boss_state = BossState.PURIFIED
	_broadcast_hp()

	if EventBus:
		EventBus.boss_defeated.emit("nakiri_ayame")
		EventBus.character_unlocked.emit("nakiri_ayame")

	if GameManager:
		GameManager.unlock_character("nakiri_ayame")
		GameManager.set_story_flag("gym_cleared_nakiri_ayame", true)

	purified.emit()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished

	defeated.emit(exp_reward)
	queue_free()
