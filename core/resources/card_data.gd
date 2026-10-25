class_name CardData
extends Resource

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum StatModifierType {
	ATTACK,
	SPEED,
	INTELLIGENCE,
	MAX_HP,
	DEFENSE,
	CRIT_RATE,
	CRIT_DAMAGE
}

@export_group("Identity")
@export var id: String = "card_id"
@export var title: String = "Card Title"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON

@export_group("Primary Effect")
@export var stat_type: StatModifierType = StatModifierType.ATTACK
@export var modifier_value: float = 3.0

@export_group("Secondary Effect (Optional)")
@export var has_secondary: bool = false
@export var secondary_stat_type: StatModifierType = StatModifierType.SPEED
@export var secondary_modifier_value: float = 0.0

@export_group("Rules")
@export var is_unique: bool = false
@export var weight: int = 100 # Drop chance weight

## Applies this card's stat modifications to a StatsComponent instance
func apply_to_stats(stats: StatsComponent) -> void:
	if not stats:
		return
	_apply_single_stat(stats, stat_type, modifier_value)
	if has_secondary:
		_apply_single_stat(stats, secondary_stat_type, secondary_modifier_value)

func _apply_single_stat(stats: StatsComponent, type: StatModifierType, val: float) -> void:
	match type:
		StatModifierType.ATTACK:
			stats.stat_attack += val
		StatModifierType.SPEED:
			stats.stat_speed += val
		StatModifierType.INTELLIGENCE:
			stats.stat_intelligence += val
		StatModifierType.MAX_HP:
			stats.max_hp += val
			stats.current_hp = min(stats.current_hp + val, stats.max_hp)
		StatModifierType.DEFENSE:
			stats.base_defense += val
		StatModifierType.CRIT_RATE:
			stats.crit_rate = clamp(stats.crit_rate + val, 0.0, 1.0)
		StatModifierType.CRIT_DAMAGE:
			stats.crit_damage_multiplier += val
