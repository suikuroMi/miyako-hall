# customization_component.gd
# CustomizationComponent — manages character color palettes, cosmetic skins,
# and visual accents, applying them to the entity's sprites.

class_name CustomizationComponent
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal appearance_changed(skin_id: String, tint: Color)

# ---------------------------------------------------------------------------
# Presets
# ---------------------------------------------------------------------------
const PALETTE_PRESETS: Dictionary = {
	"default": Color(1.0, 1.0, 1.0),
	"shrine_crimson": Color(1.0, 0.75, 0.8),
	"spirit_azure": Color(0.7, 0.88, 1.0),
	"midnight_shadow": Color(0.65, 0.65, 0.8),
	"solar_gold": Color(1.0, 0.95, 0.65)
}

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var current_skin_id: String = "default"
var current_tint: Color = Color.WHITE

func _ready() -> void:
	apply_customization(current_skin_id, current_tint)

## Applies skin and color palette to parent sprite/visual nodes
func apply_customization(skin_id: String, tint: Color = Color.WHITE) -> void:
	current_skin_id = skin_id
	current_tint = tint

	var parent: Node = get_parent()
	if not parent:
		return

	# Tint visual sprites on parent
	for child in parent.get_children():
		if child is CanvasItem:
			if child.is_in_group("character_visuals") or child is AnimatedSprite2D or child.name == "CharacterSprite":
				child.modulate = current_tint

	appearance_changed.emit(current_skin_id, current_tint)

func apply_palette_preset(preset_name: String) -> void:
	if PALETTE_PRESETS.has(preset_name):
		apply_customization(current_skin_id, PALETTE_PRESETS[preset_name])
