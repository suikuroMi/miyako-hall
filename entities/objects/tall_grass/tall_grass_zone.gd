# tall_grass_zone.gd
# Classic Pokémon stealth tall-grass patch.
# Conceals the player from enemy detection cones and reduces aggro radius by 65%.

class_name TallGrassZone
extends Area2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.set_meta("is_stealthed", true)
		var sprite = body.get_node_or_null("CharacterSprite")
		if not sprite:
			sprite = body.get_node_or_null("Sprite2D")
		if sprite:
			var tw := sprite.create_tween()
			tw.tween_property(sprite, "modulate:a", 0.55, 0.2)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.set_meta("is_stealthed", false)
		var sprite = body.get_node_or_null("CharacterSprite")
		if not sprite:
			sprite = body.get_node_or_null("Sprite2D")
		if sprite:
			var tw := sprite.create_tween()
			tw.tween_property(sprite, "modulate:a", 1.0, 0.2)
