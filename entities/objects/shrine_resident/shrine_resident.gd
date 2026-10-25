# shrine_resident.gd
# Rescued citizen spirit residing peacefully in Kamikitakuni Shrine hub.
# Offers ambient world-building, lore hints, and flavor dialogue.

class_name ShrineResident
extends Node2D

@export var resident_name: String = "Peaceful Villager Spirit"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var sprite: Sprite2D = $Sprite2D

const FLAVOR_DIALOGUES: Array[String] = [
	"The spiritual tea that Mio-sama brews always fills my spirit with courage!",
	"I saw a legendary white fox practicing ice katas on the northern summit...",
	"Thanks to the sacred Torii gate, the darkness of the False Moon cannot reach our sanctuary.",
	"The shrine feels so much more lively now! Have you tested the new expedition board yet?",
	"Oni swordswoman Ayame is fiercely honorable. She will protect the shrine with all her heart!"
]

var _hover_time: float = 0.0

func _ready() -> void:
	_hover_time = randf_range(0.0, TAU)
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _process(delta: float) -> void:
	_hover_time += delta * 2.5
	if sprite:
		sprite.position.y = sin(_hover_time) * 4.0

func _on_interacted(_player: Node2D) -> void:
	var line: String = FLAVOR_DIALOGUES.pick_random()
	var hud = get_tree().root.find_child("GameHUD", true, false)
	if hud and hud.has_node("DialogueBox"):
		hud.get_node("DialogueBox").start_dialogue([{
			"speaker": "🌸 " + resident_name,
			"text": line
		}])
