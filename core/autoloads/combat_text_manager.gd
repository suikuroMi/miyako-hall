# combat_text_manager.gd
# Global Autoload singleton managing floating combat text (damage numbers, crits, heals, status popups).

extends Node

var _layer: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 45 # Display above gameplay but below modal menus
	add_child(_layer)

	if EventBus:
		EventBus.entity_damaged.connect(_on_entity_damaged)

func _on_entity_damaged(entity: Node2D, amount: float, is_crit: bool) -> void:
	if not is_instance_valid(entity) or not entity.is_inside_tree():
		return

	var pos: Vector2 = entity.global_position
	# Offset slightly to entity head height
	pos.y -= 25.0
	pos.x += randf_range(-16.0, 16.0)

	if entity.is_in_group("player"):
		spawn_text(pos, "-%d" % int(amount), Color(1.0, 0.3, 0.3), 16, false)
	elif is_crit:
		spawn_text(pos, "%d 💥" % int(amount), Color(1.0, 0.85, 0.2), 20, true)
	else:
		spawn_text(pos, "%d" % int(amount), Color(0.95, 0.95, 1.0), 14, false)

## Public API to spawn custom colored floating text anywhere in world coordinates
func spawn_text(world_pos: Vector2, text: String, color: Color = Color.WHITE, font_size: int = 14, is_crit: bool = false) -> void:
	if not _layer:
		return

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Convert world coordinates to screen/viewport coordinates
	var canvas_transform = get_viewport().get_canvas_transform()
	var screen_pos = canvas_transform * world_pos
	label.position = screen_pos + Vector2(-30, -10)
	label.z_index = 100

	_layer.add_child(label)

	var tween = label.create_tween()
	var rise_dist = 45.0 if is_crit else 32.0
	var duration = 0.75 if is_crit else 0.55

	if is_crit:
		label.scale = Vector2(0.6, 0.6)
		tween.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), 0.12)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.10)

	tween.parallel().tween_property(label, "position:y", screen_pos.y - rise_dist, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_delay(duration * 0.4)
	tween.tween_callback(label.queue_free)
