# stats_component.gd
# Reusable stats Node for any entity (player, enemy, boss).
# Add as a child named "StatsComponent" in the scene tree.
# Handles: HP, EXP, leveling, level-up card choices, and stat upgrades.
# Communicates outward via EventBus (global autoload) and local signals.

class_name StatsComponent
extends Node

# ---------------------------------------------------------------------------
# Signals (local)
# ---------------------------------------------------------------------------
signal died
signal level_up_choices_changed(pending_choices: int)

# ---------------------------------------------------------------------------
# Exports — set these in the Inspector or via initialize_from_data()
# ---------------------------------------------------------------------------
@export var max_hp: float = 100.0
@export var base_defense: float = 0.0
@export var crit_rate: float = 0.05
@export var crit_damage_multiplier: float = 1.5

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var current_hp: float = 0.0
var level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 0
var pending_level_up_choices: int = 0

# Upgradeable stats
var stat_attack: float = 10.0
var stat_speed: float = 100.0
var stat_intelligence: float = 5.0

# Mana / Faith resources
var has_mana: bool = false
var max_mana: float = 100.0
var current_mana: float = 100.0
var faith_meter: float = 20.0
const MAX_FAITH_METER: float = 100.0
signal faith_meter_changed(current: float, max_val: float)

func add_faith(amount: float) -> void:
	faith_meter = clamp(faith_meter + amount, 0.0, MAX_FAITH_METER)
	faith_meter_changed.emit(faith_meter, MAX_FAITH_METER)

func is_ultimate_ready() -> bool:
	return faith_meter >= MAX_FAITH_METER

func consume_ultimate() -> bool:
	if is_ultimate_ready():
		faith_meter = 0.0
		faith_meter_changed.emit(faith_meter, MAX_FAITH_METER)
		return true
	return false

# Cards and blessings acquired during run
var acquired_cards: Array[Resource] = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	current_hp = max_hp
	exp_to_next_level = _calc_exp_to_level(1)

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Call this right after adding the component to populate stats from a
## CharacterData resource (defined in your resources/characters/ folder).
func initialize_from_data(data: CharacterData) -> void:
	max_hp                 = data.base_health
	stat_attack            = data.base_power
	stat_speed             = data.base_speed
	stat_intelligence      = data.base_intelligence
	base_defense           = data.base_defense
	crit_rate              = data.crit_rate
	crit_damage_multiplier = data.crit_damage

	# Apply permanent Faith Web / Talent Tree upgrades for Player
	if get_parent().is_in_group("player") and GameManager:
		max_hp += GameManager.get_talent_hp_bonus() + GameManager.talisman_hp_bonus
		stat_attack += GameManager.get_talent_attack_bonus()
		stat_speed += GameManager.get_talent_speed_bonus() * 100.0 + GameManager.talisman_speed_bonus
		crit_rate += GameManager.get_talent_crit_bonus()

	current_hp             = max_hp
	has_mana               = data.mana if "mana" in data else false
	max_mana               = data.base_mana if ("base_mana" in data and data.base_mana > 0.0) else 100.0
	current_mana           = max_mana
	
	if get_parent().is_in_group("player") and has_mana:
		EventBus.player_mana_changed.emit(current_mana, max_mana)

# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## Apply incoming raw damage. Pass is_crit = true when a critical hit is
## confirmed by the attack system.
func take_damage(raw_amount: float, is_crit: bool = false) -> void:
	var effective_damage: float = max(raw_amount - base_defense, 1.0)
	if is_crit:
		effective_damage *= crit_damage_multiplier

	current_hp = clamp(current_hp - effective_damage, 0.0, max_hp)

	# Notify EventBus — HP bar and HUD listen here
	if get_parent().is_in_group("player"):
		EventBus.player_hp_changed.emit(current_hp, max_hp)

	# Always broadcast the damage event (enemy healthbars, floating numbers, etc.)
	EventBus.entity_damaged.emit(get_parent(), effective_damage, is_crit)

	if current_hp <= 0.0:
		died.emit()

## Restore HP by amount. Clamped to max_hp.
func heal(amount: float) -> void:
	current_hp = clamp(current_hp + amount, 0.0, max_hp)

	if get_parent().is_in_group("player"):
		EventBus.player_hp_changed.emit(current_hp, max_hp)

## Fully restores HP and Mana
func heal_full() -> void:
	current_hp = max_hp
	if has_mana:
		current_mana = max_mana
	if get_parent().is_in_group("player"):
		EventBus.player_hp_changed.emit(current_hp, max_hp)
		if has_mana:
			EventBus.player_mana_changed.emit(current_mana, max_mana)

## Check if entity has enough mana
func has_enough_mana(cost: float) -> bool:
	if not has_mana or cost <= 0.0:
		return true
	return current_mana >= cost

## Consume mana for skills
func use_mana(cost: float) -> bool:
	if not has_mana or cost <= 0.0:
		return true
	if current_mana >= cost:
		current_mana = max(current_mana - cost, 0.0)
		if get_parent().is_in_group("player"):
			EventBus.player_mana_changed.emit(current_mana, max_mana)
		return true
	return false

## Restore mana
func restore_mana(amount: float) -> void:
	if not has_mana:
		return
	current_mana = clamp(current_mana + amount, 0.0, max_mana)
	if get_parent().is_in_group("player"):
		EventBus.player_mana_changed.emit(current_mana, max_mana)

# ---------------------------------------------------------------------------
# Progression
# ---------------------------------------------------------------------------

## Add EXP. Only meaningful for the player (group "player").
## Handles multi-level-up in one call.
func add_experience(amount: int) -> void:
	if not get_parent().is_in_group("player"):
		return

	current_exp += amount
	var leveled_up: bool = false

	while current_exp >= exp_to_next_level:
		current_exp       -= exp_to_next_level
		level             += 1
		pending_level_up_choices += 1
		exp_to_next_level  = _calc_exp_to_level(level)
		leveled_up         = true

	EventBus.player_exp_changed.emit(current_exp, exp_to_next_level, level)

	if leveled_up:
		EventBus.player_leveled_up.emit(level)
		level_up_choices_changed.emit(pending_level_up_choices)

## Apply a modular CardData resource chosen from level up or chest
func apply_card_resource(card: CardData) -> void:
	if not card:
		return
	card.apply_to_stats(self)
	acquired_cards.append(card)

	if pending_level_up_choices > 0:
		pending_level_up_choices -= 1

	if get_parent().is_in_group("player"):
		EventBus.player_hp_changed.emit(current_hp, max_hp)
		EventBus.player_stats_changed.emit()
		EventBus.card_selected.emit(card)

	level_up_choices_changed.emit(pending_level_up_choices)

## Apply a card upgrade chosen from the level-up selection screen.
## choice_id matches the keys used in level_up_cards.gd.
func apply_card_upgrade(choice_id: String) -> void:
	if pending_level_up_choices <= 0:
		return

	match choice_id:
		"ATK":
			stat_attack += 3.0
		"SPD":
			stat_speed += 2.0
		"INT":
			stat_intelligence += 2.0
		"VIT":
			max_hp    += 20.0
			current_hp = min(current_hp + 20.0, max_hp)

	pending_level_up_choices -= 1

	# Broadcast so HUD and stat panels can refresh
	if get_parent().is_in_group("player"):
		EventBus.player_hp_changed.emit(current_hp, max_hp)
		EventBus.player_stats_changed.emit()

	level_up_choices_changed.emit(pending_level_up_choices)

# ---------------------------------------------------------------------------
# Stat accessors (weapon bonuses included)
# ---------------------------------------------------------------------------

## Returns total attack factoring in an optional equipped weapon Resource.
## The weapon Resource is expected to optionally have a `damage_bonus` property.
func get_total_attack(equipped_weapon: Resource = null) -> float:
	var base: float = stat_attack
	if equipped_weapon and "damage_bonus" in equipped_weapon:
		base += equipped_weapon.damage_bonus
	if get_parent().is_in_group("player") and GameManager and not GameManager.active_meal_buff.is_empty():
		base *= float(GameManager.active_meal_buff.get("attack_mult", 1.0))
	return base

## Returns total speed factoring in an optional equipped weapon Resource.
## The weapon Resource is expected to optionally have a `speed_bonus` property.
func get_total_speed(equipped_weapon: Resource = null) -> float:
	var base: float = stat_speed
	if equipped_weapon and "speed_bonus" in equipped_weapon:
		base += equipped_weapon.speed_bonus
	if get_parent().is_in_group("player") and GameManager and not GameManager.active_meal_buff.is_empty():
		base *= float(GameManager.active_meal_buff.get("speed_mult", 1.0))
	return base

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _calc_exp_to_level(lv: int) -> int:
	return int(100.0 * pow(lv, 1.5))
