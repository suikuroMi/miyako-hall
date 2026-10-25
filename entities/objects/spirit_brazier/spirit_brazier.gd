# spirit_brazier.gd
# Interactive puzzle brazier / spirit lantern in Gyms.
# Lighting all braziers shatters the protective ward guarding the Gym Leader.

class_name SpiritBrazier
extends Node2D

signal lit(brazier_id: String)

@export var brazier_id: String = "brazier_1"
@export var is_lit: bool = false

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interact)
	_update_visuals()

func _on_interact(_player: Node2D) -> void:
	if is_lit:
		return
	is_lit = true
	_update_visuals()
	lit.emit(brazier_id)
	if AudioManager:
		AudioManager.play_sfx("coin")

func _update_visuals() -> void:
	if sprite:
		if is_lit:
			sprite.modulate = Color(1.5, 1.2, 0.4, 1.0) # Bright burning flame
		else:
			sprite.modulate = Color(0.4, 0.4, 0.5, 0.8) # Dormant stone
