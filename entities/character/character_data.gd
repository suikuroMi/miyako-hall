extends Resource
class_name CharacterData

@export var name: String
@export var id: String
@export var icon: Texture2D

@export var base_health: float 
@export var base_power: float 
@export var base_speed: float 
@export var base_intelligence: int 
@export var mana: bool 
@export var base_mana: float

@export var character_visual_scene: PackedScene
@export var anim_library: String