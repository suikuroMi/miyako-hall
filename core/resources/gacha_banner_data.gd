class_name GachaBannerData
extends Resource

@export_group("Banner Info")
@export var id: String = "standard_banner"
@export var banner_name: String = "Kamikitakuni Shrine Banner"
@export_multiline var description: String = "Summon venerable Holomembers and sacred spiritual arms!"
@export var banner_image: Texture2D
@export var cost_per_pull: int = 100

@export_group("Featured Rate-Up")
@export var featured_character: Resource
@export var featured_weapon: Resource

@export_group("Gacha Pool")
@export var pool_characters: Array[Resource] = []
@export var pool_weapons: Array[Resource] = []

@export_group("Rates")
@export var character_rate: float = 0.30
@export var weapon_rate: float = 0.70
