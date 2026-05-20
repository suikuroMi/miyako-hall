extends Control

var _player: Node2D
var _mini_camera: Camera2D

func _ready():
    self.process_mode = Node.PROCESS_MODE_ALWAYS
    self.visible = true
    
    _player = get_tree().root.find_child("Player", true, false)
    _mini_camera = get_node("ColorRect/SubViewportContainer/SubViewport/Camera2D")
    
    var sub_viewport = get_node("ColorRect/SubViewportContainer/SubViewport")
    if sub_viewport:
        sub_viewport.world_2d = get_tree().root.get_viewport().world_2d

    var inventory_node = get_parent().get_node("Inventory")
    if inventory_node:
        inventory_node.visibility_changed.connect(_on_inventory_visibility_changed)

func _process(_delta):
    if _player and _mini_camera:
        _mini_camera.global_position = _player.global_position

func _on_inventory_visibility_changed():
    var inventory_node = get_parent().get_node("Inventory")
    if inventory_node:
        self.visible = !inventory_node.visible