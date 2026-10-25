extends PanelContainer

var _player: Node
var _card_pool: Array[CardData] = []
var _current_choices: Array[CardData] = []
var _active_archetype_counts: Dictionary = {
	"Purification": 0,
	"Blade": 0,
	"Fox": 0
}

var _banished_card_ids: Array[String] = []
var _pending_choices_cache: int = 0

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
	"haste_blessing": "Fox",
	"blood_moon_pact": "Curse",
	"stigmata_greed": "Curse"
}

const ARCHETYPE_ICONS: Dictionary = {
	"Purification": "✨ [Purification Spells]",
	"Blade": "⚔️ [Physical Blade]",
	"Fox": "🦊 [Spirit Fox Swiftness]",
	"Curse": "🌑 [Cursed Stigma]"
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

	var reroll = get_node_or_null("Content/ActionsRow/RerollBtn")
	if reroll:
		reroll.pressed.connect(reroll_choices)
	var banish = get_node_or_null("Content/ActionsRow/BanishBtn")
	if banish:
		banish.pressed.connect(func(): banish_choice(0))

	if "pending_level_up_choices" in _player:
		_on_level_up_choices_changed(_player.pending_level_up_choices)

func _load_card_pool() -> void:
	var card_paths := [
		"res://data/cards/faith_surge.tres",
		"res://data/cards/haste_blessing.tres",
		"res://data/cards/divine_barrier.tres",
		"res://data/cards/celestial_crit.tres",
		"res://data/cards/spirit_font.tres",
		"res://data/cards/blood_moon_pact.tres",
		"res://data/cards/stigmata_greed.tres"
	]
	for path in card_paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is CardData and res.id not in _banished_card_ids:
				_card_pool.append(res)

func _on_level_up_choices_changed(pending_choices: int) -> void:
	_pending_choices_cache = pending_choices
	if pending_choices <= 0:
		visible = false
		get_tree().paused = false
		return

	_show_new_choices(pending_choices)
	visible = true
	get_tree().paused = true

func _show_new_choices(pending_choices: int) -> void:
	_pending_choices_cache = pending_choices
	var synergy_hint := ""
	for arch in _active_archetype_counts.keys():
		var count: int = _active_archetype_counts[arch]
		if count >= 2:
			synergy_hint += " | %s SET BONUS ACTIVE! (x%d)" % [arch.to_upper(), count]

	_title_label.text = "LEVEL UP! Choose 1 Blessing (%d remaining)%s" % [pending_choices, synergy_hint]

	var available_pool: Array[CardData] = []
	for c in _card_pool:
		if c.id not in _banished_card_ids:
			available_pool.append(c)

	if available_pool.size() >= 3:
		var pool := available_pool.duplicate()
		pool.shuffle()
		_current_choices = [pool[0], pool[1], pool[2]]
	else:
		_current_choices = available_pool.duplicate()

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

func reroll_choices() -> void:
	if not GameManager or GameManager.shrine_coins < 25:
		return
	GameManager.shrine_coins -= 25
	if EventBus:
		EventBus.currency_changed.emit(GameManager.shrine_coins)
	if AudioManager:
		AudioManager.play_sfx("coin")
	_show_new_choices(_pending_choices_cache)

func banish_choice(index: int) -> void:
	if not GameManager or GameManager.shrine_coins < 35:
		return
	if index < 0 or index >= _current_choices.size():
		return
	var card_to_banish: CardData = _current_choices[index]
	_banished_card_ids.append(card_to_banish.id)
	GameManager.shrine_coins -= 35
	if EventBus:
		EventBus.currency_changed.emit(GameManager.shrine_coins)
	if AudioManager:
		AudioManager.play_sfx("purified")
	_show_new_choices(_pending_choices_cache)

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
