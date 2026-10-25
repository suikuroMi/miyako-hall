# object_pool.gd
# Global Autoload singleton providing high-performance object pooling
# for projectiles, enemies, and visual particle bursts. Eliminates GC frame drops.

extends Node

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
# Dictionary of scene_path -> Array[Node] (inactive instances)
var _pools: Dictionary = {}

# Dedicated Bullet Scene reference
var _bullet_scene: PackedScene = preload("res://entities/objects/bullet/bullet.tscn")

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Prewarm bullet pool with 40 instances
	call_deferred("_prewarm_defaults")

func _prewarm_defaults() -> void:
	if _bullet_scene:
		prewarm(_bullet_scene, 40)

# ---------------------------------------------------------------------------
# Public Pooling API
# ---------------------------------------------------------------------------

## Pre-allocates a quantity of scene instances into the pool
func prewarm(scene: PackedScene, count: int) -> void:
	if not scene:
		return
	var key: String = scene.resource_path
	if not _pools.has(key):
		_pools[key] = []

	for i in range(count):
		var inst: Node = scene.instantiate()
		_deactivate_instance(inst)
		add_child(inst)
		_pools[key].append(inst)

## Spawns an instance from the pool (or creates a new one if pool is depleted)
func spawn(scene: PackedScene, parent: Node = null) -> Node:
	if not scene:
		return null
	var key: String = scene.resource_path
	var inst: Node = null

	if _pools.has(key) and _pools[key].size() > 0:
		inst = _pools[key].pop_back()
	else:
		inst = scene.instantiate()
		inst.set_meta("pool_key", key)

	if not inst.has_meta("pool_key"):
		inst.set_meta("pool_key", key)

	# Attach to requested parent or current scene
	var target_parent: Node = parent if parent else get_tree().current_scene
	if inst.get_parent() != target_parent:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		target_parent.add_child(inst)

	_activate_instance(inst)
	return inst

## Returns an active instance back to the inactive pool
func recycle(instance: Node) -> void:
	if not is_instance_valid(instance):
		return

	var key: String = instance.get_meta("pool_key", "")
	if key == "":
		instance.queue_free()
		return

	if not _pools.has(key):
		_pools[key] = []

	_deactivate_instance(instance)

	if instance.get_parent() != self:
		if instance.get_parent():
			instance.get_parent().remove_child(instance)
		add_child(instance)

	_pools[key].append(instance)

# ---------------------------------------------------------------------------
# Bullet Convenience Helper
# ---------------------------------------------------------------------------

## Spawns and configures a pooled bullet projectile
func spawn_bullet(pos: Vector2, rot: float, dmg: float = 15.0, spd: float = 900.0, rng: float = 1200.0, team: int = 0) -> Node:
	var b: Node = spawn(_bullet_scene)
	if not b:
		return null

	b.global_position = pos
	b.rotation = rot
	if "damage" in b:
		b.damage = dmg
	if "speed" in b:
		b.speed = spd
	if "range" in b:
		b.range = rng
	if "team" in b:
		b.team = team
	if "_travelled" in b:
		b._travelled = 0.0

	return b

# ---------------------------------------------------------------------------
# Internal Activation / Deactivation
# ---------------------------------------------------------------------------

func _activate_instance(inst: Node) -> void:
	if inst is CanvasItem:
		inst.visible = true
	inst.set_process(true)
	inst.set_physics_process(true)

	if inst is CollisionObject2D:
		inst.set_collision_layer_value(1, true)
		if inst is Area2D:
			inst.monitoring = true
			inst.monitorable = true

func _deactivate_instance(inst: Node) -> void:
	if inst is CanvasItem:
		inst.visible = false
	inst.set_process(false)
	inst.set_physics_process(false)

	if inst is CollisionObject2D:
		if inst is Area2D:
			inst.monitoring = false
			inst.monitorable = false
