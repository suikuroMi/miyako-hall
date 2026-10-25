# skill_caster_component.gd
# SkillCasterComponent — manages active character skills (Q, E, R), cooldowns,
# mana/faith costs, and executes offensive or supportive effects.

class_name SkillCasterComponent
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal skill_equipped(slot: String, skill_data: SkillData)
signal skill_cast_success(slot: String, skill_data: SkillData)
signal skill_cooldown_updated(slot: String, current: float, max_time: float)

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var team: int = 0 # 0 = player, 1 = enemy
@export var skill_q: SkillData
@export var skill_e: SkillData
@export var skill_r: SkillData

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var _skills: Dictionary = {
	"Q": null,
	"E": null,
	"R": null
}

var _cooldowns: Dictionary = {
	"Q": 0.0,
	"E": 0.0,
	"R": 0.0
}

var _max_cooldowns: Dictionary = {
	"Q": 1.0,
	"E": 1.0,
	"R": 1.0
}

var _stats: StatsComponent = null
var _movement: MovementComponent = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_stats = get_parent().get_node_or_null("StatsComponent")
	_movement = get_parent().get_node_or_null("MovementComponent")
	
	if skill_q:
		equip_skill("Q", skill_q)
	if skill_e:
		equip_skill("E", skill_e)
	if skill_r:
		equip_skill("R", skill_r)

func _process(delta: float) -> void:
	for slot in _cooldowns.keys():
		if _cooldowns[slot] > 0.0:
			_cooldowns[slot] = max(_cooldowns[slot] - delta, 0.0)
			skill_cooldown_updated.emit(slot, _cooldowns[slot], _max_cooldowns[slot])
			if get_parent() and get_parent().is_in_group("player"):
				EventBus.skill_cooldown_updated.emit(slot, _cooldowns[slot], _max_cooldowns[slot])

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Equips a skill into slot "Q", "E", or "R".
func equip_skill(slot: String, skill: SkillData) -> void:
	slot = slot.to_upper()
	if not _skills.has(slot):
		return
	_skills[slot] = skill
	_cooldowns[slot] = 0.0
	_max_cooldowns[slot] = skill.cooldown if skill else 1.0
	skill_equipped.emit(slot, skill)
	skill_cooldown_updated.emit(slot, 0.0, _max_cooldowns[slot])
	if get_parent() and get_parent().is_in_group("player"):
		EventBus.skill_cooldown_updated.emit(slot, 0.0, _max_cooldowns[slot])

## Loads skills from CharacterData if defined on it
func load_from_character_data(data: CharacterData) -> void:
	if not data:
		return
	if "skill_q" in data and data.skill_q is SkillData:
		equip_skill("Q", data.skill_q)
	else:
		equip_skill("Q", null)

	if "skill_e" in data and data.skill_e is SkillData:
		equip_skill("E", data.skill_e)
	else:
		equip_skill("E", null)

	if "skill_r" in data and data.skill_r is SkillData:
		equip_skill("R", data.skill_r)
	else:
		equip_skill("R", null)

## Returns true if the skill in slot can be cast
func can_cast(slot: String) -> bool:
	slot = slot.to_upper()
	if not _skills.has(slot) or _skills[slot] == null:
		return false
	if _cooldowns[slot] > 0.0:
		return false
	var skill: SkillData = _skills[slot]
	if _stats and skill.mana_cost > 0.0:
		if not _stats.has_enough_mana(skill.mana_cost):
			return false
	return true

## Casts the skill in the given slot
func cast_skill(slot: String) -> bool:
	slot = slot.to_upper()
	if not can_cast(slot):
		return false

	var skill: SkillData = _skills[slot]

	# Consume mana if applicable
	if _stats and skill.mana_cost > 0.0:
		_stats.use_mana(skill.mana_cost)

	# Start cooldown
	_max_cooldowns[slot] = skill.cooldown
	_cooldowns[slot] = skill.cooldown

	# Perform the skill's mechanical action
	_execute_skill_effect(skill)

	skill_cast_success.emit(slot, skill)
	if get_parent() and get_parent().is_in_group("player"):
		EventBus.skill_cast.emit(slot, skill)
		EventBus.skill_cooldown_updated.emit(slot, _cooldowns[slot], _max_cooldowns[slot])
		if AudioManager:
			AudioManager.play_sfx("skill")

	return true

func get_skill(slot: String) -> SkillData:
	slot = slot.to_upper()
	return _skills.get(slot, null)

func get_cooldown_remaining(slot: String) -> float:
	slot = slot.to_upper()
	return _cooldowns.get(slot, 0.0)

func get_max_cooldown(slot: String) -> float:
	slot = slot.to_upper()
	return _max_cooldowns.get(slot, 1.0)

# ---------------------------------------------------------------------------
# Internal Execution
# ---------------------------------------------------------------------------

func _execute_skill_effect(skill: SkillData) -> void:
	var parent: Node2D = get_parent() as Node2D
	if not parent:
		return

	# Damage calculation with scaling
	var final_damage: float = skill.base_damage
	if _stats:
		var stat_val: float = _stats.stat_attack if skill.scaling_stat == "attack" else _stats.stat_intelligence
		final_damage += stat_val * skill.damage_scaling

		# If casting R and ultimate faith is full, trigger amplified Grand Ultimate!
		if skill.slot == "R" and _stats.consume_ultimate():
			final_damage *= 2.0
			if CameraManager:
				CameraManager.shake(15.0, 0.45)
		else:
			_stats.add_faith(12.0)

	match skill.skill_type:
		SkillData.SkillType.AOE_DAMAGE:
			_cast_aoe_damage(parent.global_position, skill.radius, final_damage, skill.knockback_force, skill)

		SkillData.SkillType.PROJECTILE:
			_cast_projectiles(parent, skill, final_damage)

		SkillData.SkillType.DASH_ATTACK:
			_cast_dash_attack(parent, skill, final_damage)

		SkillData.SkillType.HEAL_SUPPORT:
			if _stats and skill.heal_amount > 0.0:
				_stats.heal(skill.heal_amount)
			if skill.radius > 0.0 and final_damage > 0.0:
				_cast_aoe_damage(parent.global_position, skill.radius, final_damage, skill.knockback_force, skill)

		SkillData.SkillType.BUFF:
			if _stats and skill.heal_amount > 0.0:
				_stats.heal(skill.heal_amount)
			if _movement and skill.speed_boost > 0.0 and skill.buff_duration > 0.0:
				_apply_speed_buff(skill.speed_boost, skill.buff_duration)

func _apply_elemental_reaction(target: Node, skill: SkillData) -> void:
	if not is_instance_valid(target):
		return
	var status: StatusEffectComponent = target.get_node_or_null("StatusEffectComponent")
	if not status:
		status = StatusEffectComponent.new()
		status.name = "StatusEffectComponent"
		target.add_child(status)

	var s_name: String = skill.id.to_lower()
	if "blizzard" in s_name or "frost" in s_name or "ice" in s_name:
		status.apply_element(StatusEffectComponent.ElementType.FROST)
	elif "flame" in s_name or "oni" in s_name or "fire" in s_name:
		status.apply_element(StatusEffectComponent.ElementType.BURN)
	elif "tarot" in s_name or "purif" in s_name or "curse" in s_name or "spirit" in s_name:
		status.apply_element(StatusEffectComponent.ElementType.CURSE)

func _cast_aoe_damage(center: Vector2, radius: float, damage: float, knockback: float, skill: SkillData = null) -> void:
	var target_group: String = "enemies" if team == 0 else "player"
	var targets: Array[Node] = get_tree().get_nodes_in_group(target_group)
	for t in targets:
		if not is_instance_valid(t) or not (t is Node2D):
			continue
		var dist: float = center.distance_to(t.global_position)
		if dist <= radius:
			if t.has_method("take_damage"):
				t.take_damage(damage)
			if skill:
				_apply_elemental_reaction(t, skill)
			for child in t.get_children():
				if child is HurtboxComponent and child.team != team:
					child.receive_damage(damage, knockback, center)
					break

func _cast_projectiles(parent: Node2D, skill: SkillData, damage: float) -> void:
	var proj_scene: PackedScene = skill.projectile_scene
	if not proj_scene:
		proj_scene = preload("res://entities/objects/bullet/bullet.tscn")

	var target_pos: Vector2 = parent.get_global_mouse_position() if parent.is_in_group("player") else (parent.global_position + Vector2.RIGHT)
	var base_direction: Vector2 = (target_pos - parent.global_position).normalized()
	if base_direction.is_zero_approx():
		base_direction = Vector2.RIGHT

	var count: int = max(skill.projectile_count, 1)
	var start_angle: float = 0.0
	var angle_step: float = 0.0
	if count > 1:
		var total_spread_rad: float = deg_to_rad(skill.projectile_spread)
		start_angle = -total_spread_rad / 2.0
		angle_step = total_spread_rad / float(count - 1)

	for i in range(count):
		var proj = proj_scene.instantiate()
		var dir = base_direction.rotated(start_angle + i * angle_step)
		proj.global_position = parent.global_position
		proj.rotation = dir.angle()
		if "damage" in proj:
			proj.damage = damage
		if "speed" in proj:
			proj.speed = skill.projectile_speed
		if "range" in proj:
			proj.range = skill.projectile_range
		if "team" in proj:
			proj.team = team
		get_tree().current_scene.add_child(proj)

func _cast_dash_attack(parent: Node2D, skill: SkillData, damage: float) -> void:
	var target_pos: Vector2 = parent.get_global_mouse_position() if parent.is_in_group("player") else (parent.global_position + Vector2.RIGHT)
	var dir: Vector2 = (target_pos - parent.global_position).normalized()
	if dir.is_zero_approx():
		dir = Vector2.RIGHT

	if _movement:
		_movement.apply_knockback(dir * skill.dash_speed)
	elif parent is CharacterBody2D:
		parent.velocity = dir * skill.dash_speed

	if skill.radius > 0.0 and damage > 0.0:
		_cast_aoe_damage(parent.global_position, skill.radius, damage, skill.knockback_force)

func _apply_speed_buff(speed_bonus: float, duration: float) -> void:
	if not _movement:
		return
	_movement.base_speed += speed_bonus
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(_movement):
			_movement.base_speed -= speed_bonus
	)
