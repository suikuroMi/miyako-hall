# weapon_data.gd
# Dedicated weapon resource extending ItemData.
# Works seamlessly in Inventory slots and connects directly to WeaponPivotComponent.

class_name WeaponData
extends ItemData

# Weapon archetypes mapping to CharacterData.WeaponType enum
enum WeaponType { SWORD, GREATSWORD, SCYTHE, GUN, TALISMAN }

@export_group("Weapon Archetype")
@export var display_name: String = "Weapon"
@export var weapon_type: WeaponType = WeaponType.SWORD

@export_group("Stats")
@export var attack_speed: float = 1.0        # attacks per second (used by WeaponPivot cooldown)
@export var attack_range: float = 80.0       # pixels — melee swing radius or bullet range
@export var knockback_force: float = 120.0
@export var damage_bonus: float = 0.0        # added on top of player's stat_attack
@export var speed_bonus: float = 0.0         # added to movement speed
@export_range(0.0, 1.0) var crit_chance_bonus: float = 0.0

@export_group("Behaviour")
# If true: spawns a projectile from weapon_pivot on attack. If false: activates melee HitboxComponent.
@export var is_ranged: bool = false
@export var projectile_scene: PackedScene     # only used if is_ranged = true
@export var swing_duration: float = 0.15     # how long the melee hitbox stays active

@export_group("Synergy")
# When equipped by a character whose favored_weapon matches weapon_type,
# these bonuses are applied on top of base stats.
@export var synergy_damage_bonus: float = 0.0
@export var synergy_speed_bonus: float = 0.0
@export var synergy_cooldown_reduction: float = 0.0   # 0.0–1.0, fraction reduction to attack_speed cooldown

func _init() -> void:
	type = "weapon"
	stackable = false
	if display_name != "" and (name == "" or name == "Item"):
		name = display_name
