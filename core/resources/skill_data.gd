class_name SkillData
extends Resource

enum SkillType {
	AOE_DAMAGE,
	PROJECTILE,
	DASH_ATTACK,
	HEAL_SUPPORT,
	BUFF
}

@export_group("Identity")
@export var id: String = "skill_id"
@export var display_name: String = "Skill"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var skill_type: SkillType = SkillType.AOE_DAMAGE

@export_group("Cost & Cooldown")
@export var cooldown: float = 4.0
@export var mana_cost: float = 0.0

@export_group("Combat Values")
@export var base_damage: float = 25.0
@export var damage_scaling: float = 1.0 # Multiplier against attack or intelligence
@export var scaling_stat: String = "attack" # "attack" or "intelligence"
@export var knockback_force: float = 150.0
@export var radius: float = 100.0 # AoE radius for AOE_DAMAGE or DASH_ATTACK

@export_group("Projectile (if PROJECTILE)")
@export var projectile_scene: PackedScene
@export var projectile_count: int = 1
@export var projectile_spread: float = 15.0 # Degrees spread
@export var projectile_speed: float = 700.0
@export var projectile_range: float = 800.0

@export_group("Dash (if DASH_ATTACK)")
@export var dash_speed: float = 450.0
@export var dash_duration: float = 0.2

@export_group("Heal / Buff")
@export var heal_amount: float = 0.0
@export var buff_duration: float = 0.0
@export var speed_boost: float = 0.0
