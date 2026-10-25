# mouse_item.gd
# TextureRect that follows the mouse cursor and displays the item currently
# being dragged in the inventory.
#
# CHANGE: Removed _physics_process polling. State is now refreshed explicitly
# via refresh(), which slot.gd should call whenever it updates this node's
# `data` or `count` properties.
#
# Usage in slot.gd:
#   mouse_item.data  = item_data
#   mouse_item.count = item_count
#   mouse_item.refresh()

extends TextureRect

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var data: ItemData  = null
@export var count: int  = 0

# ---------------------------------------------------------------------------
# Child references
# ---------------------------------------------------------------------------
@onready var count_label: Label = get_node("Count")

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	refresh()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Synchronise the visual state with the current data / count values.
## Call this from slot.gd (or wherever data/count are mutated) instead of
## relying on _physics_process.
func refresh() -> void:
	# Clear data reference when there's nothing to display
	if count <= 0:
		data = null

	# Update count label
	count_label.text    = str(count)
	count_label.visible = count > 1

	# Update texture
	if data != null:
		texture = data.texture
	else:
		texture = null
