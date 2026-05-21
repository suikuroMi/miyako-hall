extends Control

@onready var _story_button: Button = $MenuContainer/Content/ButtonsContainer/StoryButton
@onready var _endless_button: Button = $MenuContainer/Content/ButtonsContainer/EndlessButton
@onready var _options_button: Button = $MenuContainer/Content/ButtonsContainer/OptionsButton
@onready var _credits_button: Button = $MenuContainer/Content/ButtonsContainer/CreditsButton
@onready var _exit_button: Button = $MenuContainer/Content/ButtonsContainer/ExitButton
@onready var _menu_container: CenterContainer = $MenuContainer

@onready var _credits_panel: PanelContainer = $CreditsPanel
@onready var _credits_back_button: Button = $CreditsPanel/CreditsContent/BackButton

@onready var _options_panel: PanelContainer = $OptionsPanel
@onready var _options_back_button: Button = $OptionsPanel/OptionsContent/BackButton
@onready var _window_mode_button: Button = $OptionsPanel/OptionsContent/SettingsGrid/WindowModeButton

@onready var _under_construction_panel: PanelContainer = $UnderConstructionPanel
@onready var _under_construction_back_button: Button = $UnderConstructionPanel/ConstructionContent/BackButton

func _ready():
	_story_button.pressed.connect(_on_story_mode_pressed)
	_endless_button.pressed.connect(_on_endless_mode_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_credits_back_button.pressed.connect(_on_credits_back_pressed)
	_options_back_button.pressed.connect(_on_options_back_pressed)
	_under_construction_back_button.pressed.connect(_on_under_construction_back_pressed)
	
	_window_mode_button.pressed.connect(_on_window_mode_toggled)
	_update_window_mode_button_text()
	
	_credits_panel.visible = false
	_options_panel.visible = false
	_under_construction_panel.visible = false
	_menu_container.visible = true

func _on_story_mode_pressed():
	_menu_container.visible = false
	_under_construction_panel.visible = true

func _on_endless_mode_pressed():
	get_tree().change_scene_to_file("res://maps/modes/endless.tscn")

func _on_under_construction_back_pressed():
	_under_construction_panel.visible = false
	_menu_container.visible = true

func _on_options_pressed():
	_menu_container.visible = false
	_options_panel.visible = true

func _on_credits_pressed():
	_menu_container.visible = false
	_credits_panel.visible = true

func _on_credits_back_pressed():
	_credits_panel.visible = false
	_menu_container.visible = true

func _on_options_back_pressed():
	_options_panel.visible = false
	_menu_container.visible = true

func _on_exit_pressed():
	get_tree().quit()

func _on_window_mode_toggled():
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_update_window_mode_button_text()

func _update_window_mode_button_text():
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		_window_mode_button.text = "Fullscreen"
	else:
		_window_mode_button.text = "Windowed"
