# breakable_prop.gd
# Breakable environmental objects (Pottery Urns, Wooden Crates, Spirit Crystals).
# Shatters upon taking weapon or skill damage, releasing coins, health orbs, and crafting materials.

class_name BreakableProp
extends Area2D

enum PropType {
	POTTERY_JAR,
	WOODEN_CRATE,
	SPIRIT_CRYSTAL
}

@export var prop_type: PropType = PropType.POTTERY_JAR
@export var min_coin_reward: int = 15
@export var max_coin_reward: int = 35
@export var heals_hp: float = 0.0

var _is_broken: bool = false
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 2 # Hurtbox layer (can be struck by player weapons/hitboxes)
	collision_mask = 0
	_update_prop_visuals()

func _update_prop_visuals() -> void:
	if not sprite:
		return
	match prop_type:
		PropType.POTTERY_JAR:
			sprite.modulate = Color(0.95, 0.85, 0.7)
		PropType.WOODEN_CRATE:
			sprite.modulate = Color(0.8, 0.6, 0.4)
		PropType.SPIRIT_CRYSTAL:
			sprite.modulate = Color(0.6, 0.8, 1.4)

func take_damage(_amount: float = 1.0) -> void:
	if _is_broken:
		return
	_is_broken = true

	# Disable collision immediately so it cannot be hit twice
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var reward: int = randi_range(min_coin_reward, max_coin_reward)
	if GameManager:
		GameManager.shrine_coins += reward
		if EventBus:
			EventBus.currency_changed.emit(GameManager.shrine_coins)

	if heals_hp > 0.0:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_node("StatsComponent"):
			player.get_node("StatsComponent").heal(heals_hp)

	if AudioManager:
		AudioManager.play_sfx("coin")

	if CombatTextManager:
		CombatTextManager.spawn_text(global_position + Vector2(0, -20), "+%d Coins" % reward, Color(1.0, 0.85, 0.3), 15)

	# Shatter animation & debris
	_shatter_effect()

func _shatter_effect() -> void:
	if not sprite:
		queue_free()
		return

	# Scatter fragments using duplicate sprites fading out
	for i in range(4):
		var shard := Sprite2D.new()
		shard.texture = sprite.texture
		shard.modulate = sprite.modulate
		shard.scale = sprite.scale * 0.45
		shard.global_position = global_position
		get_parent().add_child(shard)

		var dir := Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(30, 60)
		var tw := shard.create_tween()
		tw.parallel().tween_property(shard, "position", shard.position + dir, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(shard, "rotation", randf_range(-PI, PI), 0.35)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.35)
		tw.tween_callback(shard.queue_free)

	queue_free()
