# character_data.gd
# Data container for player characters, unlockable Holomembers, and boss profiles.

class_name CharacterData
extends Resource

enum Archetype {
	SHRINE_MAIDEN,
	VANGUARD,
	ASSASSIN,
	REAPER,
	MARKSMAN,
}

enum WeaponType { SWORD, GREATSWORD, SCYTHE, GUN, TALISMAN }

@export_group("Identity")
@export var name: String = "Character"
@export var id: String = "character"
@export var description: String = ""
@export var icon: Texture2D
@export var archetype: Archetype = Archetype.SHRINE_MAIDEN
@export var favored_weapon: WeaponType = WeaponType.TALISMAN

@export_group("Visuals")
@export var character_visual_scene: PackedScene
@export var sprite_frames: SpriteFrames
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var base_scale: Vector2 = Vector2.ONE
@export var anim_library: String = ""

@export_group("Base Stats (Level 1)")
@export var base_health: float = 100.0
@export var base_power: float = 20.0
@export var base_speed: float = 30.0
@export var base_intelligence: int = 15
@export var mana: bool = true
@export var base_mana: float = 100.0

@export var base_defense: float = 5.0
@export_range(0.0, 1.0) var crit_rate: float = 0.05
@export var crit_damage: float = 1.5

@export_group("Level Growth")
@export var hp_per_level: float = 15.0
@export var atk_per_level: float = 3.0
@export var def_per_level: float = 1.2

@export_group("Skills")
@export var skill_q: Resource
@export var skill_e: Resource
@export var skill_r: Resource

@export_group("Enemy Settings")
@export var exp_drop: int = 25
@export var detection_radius: float = 160.0
@export var lose_sight_radius: float = 260.0
