extends PanelContainer

var _player: Node
var _card_pool: Array[CardData] = []
var _current_choices: Array[CardData] = []
var _active_archetype_counts: Dictionary = {
	"Purification": 0,
	"Blade": 0,
	"Fox": 0
}

@onready var _title_label: Label = $Content/TitleLabel
@onready var _card_a: Button = $Content/CardsRow/CardA
@onready var _card_b: Button = $Content/CardsRow/CardB
@onready var _card_c: Button = $Content/CardsRow/CardC

const RARITY_NAMES: Array[String] = ["COMMON", "RARE", "EPIC", "LEGENDARY"]
const RARITY_COLORS: Array[Color] = [
	Color(0.8, 0.8, 0.8),
	Color(0.3, 0.7, 1.0),
	Color(0.8, 0.4, 1.0),
	Color(1.0, 0.8, 0.2)
]

const ARCHETYPE_MAP: Dictionary = {
	"faith_surge": "Purification",
	"spirit_font": "Purification",
	"celestial_crit": "Blade",
	"divine_barrier": "Blade",
	"haste_blessing": "Fox"
}

const ARCHETYPE_ICONS: Dictionary = {
	"Purification": "✨ [Purification Spells]",
	"Blade": "⚔️ [Physical Blade]",
	"Fox": "🦊 [Spirit Fox Swiftness]"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	_load_card_pool()

	_player = get_tree().root.find_child("Player", true, false)
	if not _player:
		return

	if _player.has_signal("level_up_choices_changed"):
		_player.level_up_choices_changed.connect(_on_level_up_choices_changed)

	_card_a.pressed.connect(_on_card_pressed.bind(0))
	_card_b.pressed.connect(_on_card_pressed.bind(1))
	_card_c.pressed.connect(_on_card_pressed.bind(2))

	if "pending_level_up_choices" in _player:
		_on_level_up_choices_changed(_player.pending_level_up_choices)

func _load_card_pool() -> void:
	var card_paths := [
		"res://data/cards/faith_surge.tres",
		"res://data/cards/haste_blessing.tres",
		"res://data/cards/divine_barrier.tres",
		"res://data/cards/celestial_crit.tres",
		"res://data/cards/spirit_font.tres"
	]
	for path in card_paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is CardData:
				_card_pool.append(res)

func _on_level_up_choices_changed(pending_choices: int) -> void:
	if pending_choices <= 0:
		visible = false
		get_tree().paused = false
		return

	_show_new_choices(pending_choices)
	visible = true
	get_tree().paused = true

func _show_new_choices(pending_choices: int) -> void:
	var synergy_hint := ""
	for arch in _active_archetype_counts.keys():
		var count: int = _active_archetype_counts[arch]
		if count >= 2:
			synergy_hint += " | %s SET BONUS ACTIVE! (x%d)" % [arch.to_upper(), count]

	_title_label.text = "LEVEL UP! Choose 1 Blessing (%d remaining)%s" % [pending_choices, synergy_hint]

	if _card_pool.size() >= 3:
		var pool := _card_pool.duplicate()
		pool.shuffle()
		_current_choices = [pool[0], pool[1], pool[2]]
	else:
		_current_choices = _card_pool.duplicate()

	var buttons := [_card_a, _card_b, _card_c]
	for i in range(buttons.size()):
		if i < _current_choices.size():
			var card: CardData = _current_choices[i]
			var rarity_idx: int = clamp(int(card.rarity), 0, RARITY_NAMES.size() - 1)
			var arch_name: String = ARCHETYPE_MAP.get(card.id, "Purification")
			var arch_tag: String = ARCHETYPE_ICONS.get(arch_name, "[Blessing]")
			var active_stacks: int = _active_archetype_counts.get(arch_name, 0)
			var stack_msg: String = " (Set: %d/2)" % active_stacks if active_stacks < 2 else " (★ SET BONUS ACTIVE)"

			buttons[i].text = "[%s] %s%s\n%s\n%s" % [
				RARITY_NAMES[rarity_idx],
				arch_tag,
				stack_msg,
				card.title,
				card.description
			]
			buttons[i].visible = true
		else:
			buttons[i].visible = false

func _on_card_pressed(index: int) -> void:
	if not _player:
		return
	if index < 0 or index >= _current_choices.size():
		return

	var chosen_card: CardData = _current_choices[index]
	var arch_name: String = ARCHETYPE_MAP.get(chosen_card.id, "Purification")
	_active_archetype_counts[arch_name] = _active_archetype_counts.get(arch_name, 0) + 1

	if _player.has_method("apply_card_resource"):
		_player.apply_card_resource(chosen_card)
	elif _player.has_method("apply_level_up_choice"):
		_player.apply_level_up_choice("ATK")
