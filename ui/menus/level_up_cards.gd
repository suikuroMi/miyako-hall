extends PanelContainer

var _player: Node
var _current_choices: Array[String] = []

@onready var _title_label: Label = $Content/TitleLabel
# @onready var _cards_row: HBoxContainer = $Content/CardsRow
@onready var _card_a: Button = $Content/CardsRow/CardA
@onready var _card_b: Button = $Content/CardsRow/CardB
@onready var _card_c: Button = $Content/CardsRow/CardC

const CARD_LABELS := {
	"ATK": "ATK +3",
	"SPD": "SPD +2",
	"INT": "INT +2",
	"VIT": "MAX HP +20"
}

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	_player = get_tree().root.find_child("Player", true, false)
	if not _player:
		return

	if _player.has_signal("level_up_choices_changed"):
		_player.level_up_choices_changed.connect(_on_level_up_choices_changed)

	_card_a.pressed.connect(_on_card_pressed.bind(0))
	_card_b.pressed.connect(_on_card_pressed.bind(1))
	_card_c.pressed.connect(_on_card_pressed.bind(2))

	_on_level_up_choices_changed(_player.pending_level_up_choices)

func _on_level_up_choices_changed(pending_choices: int):
	if pending_choices <= 0:
		visible = false
		get_tree().paused = false
		return

	_show_new_choices(pending_choices)
	visible = true
	get_tree().paused = true

func _show_new_choices(pending_choices: int):
	var other_choices := ["SPD", "INT", "VIT"]
	other_choices.shuffle()
	_current_choices = ["ATK", other_choices[0], other_choices[1]]

	_title_label.text = "LEVEL UP! Choose 1 card (%d left)" % pending_choices
	_card_a.text = CARD_LABELS[_current_choices[0]]
	_card_b.text = CARD_LABELS[_current_choices[1]]
	_card_c.text = CARD_LABELS[_current_choices[2]]

func _on_card_pressed(index: int):
	if not _player:
		return
	if index < 0 or index >= _current_choices.size():
		return

	if _player.has_method("apply_level_up_choice"):
		_player.apply_level_up_choice(_current_choices[index])
