extends Control

var _player: Node2D
var _mini_camera: Camera2D

func _ready():
	_player = get_tree().root.find_child("Player", true, false)
	
	_mini_camera = get_node("ColorRect/SubViewportContainer/SubViewport/Camera2D")
	
	var sub_viewport = get_node("ColorRect/SubViewportContainer/SubViewport")
	
	if sub_viewport:
		sub_viewport.world_2d = get_tree().root.get_viewport().world_2d

func _process(_delta):
	if _player and _mini_camera:
		_mini_camera.global_position = _player.global_position
