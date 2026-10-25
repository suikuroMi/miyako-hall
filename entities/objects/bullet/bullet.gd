extends Area2D

# ---------------------------------------------------------------------------
# Properties — set by the weapon that spawned this bullet
# (WeaponPivotComponent._fire_projectile sets these before add_child)
# ---------------------------------------------------------------------------

var damage: float = 15.0
var speed: float = 900.0
var range: float = 1200.0
var team: int = 0   # 0 = player bullet (hurts enemies); 1 = enemy bullet (hurts player)

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _travelled: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var move: Vector2 = Vector2.RIGHT.rotated(rotation) * speed * delta
	position += move
	_travelled += move.length()
	if _travelled >= range:
		_destroy()

# ---------------------------------------------------------------------------
# Collision
# ---------------------------------------------------------------------------

func _on_body_entered(body: Node2D) -> void:
	_destroy()

	# Legacy path: body exposes take_damage() directly
	if body.has_method("take_damage"):
		body.take_damage(damage)

	# Preferred path: delegate to a HurtboxComponent on the body,
	# respecting team tags to avoid friendly fire.
	for child in body.get_children():
		if child is HurtboxComponent and child.team != team:
			child.receive_damage(damage, 0.0, global_position)
			return

func _destroy() -> void:
	if ObjectPool:
		ObjectPool.recycle(self)
	else:
		queue_free()
