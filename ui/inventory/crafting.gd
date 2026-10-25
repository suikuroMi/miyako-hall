extends Control

@onready var craft_slots: GridContainer = get_node_or_null("CraftingSlots")
@onready var craft_output: Button = get_node_or_null("Output")

@export var curr_recipe: Array[String] = ["", "", "", "", "", "", "", "", ""]

func _ready() -> void:
	if craft_slots:
		if curr_recipe.size() != craft_slots.get_child_count():
			curr_recipe.resize(craft_slots.get_child_count())
			curr_recipe.fill("")

		for i in craft_slots.get_child_count():
			var slot = craft_slots.get_child(i)
			if "craft_index" in slot:
				slot.craft_index = i

func update_recipe(index: int, id: String) -> void:
	if index >= 0 and index < curr_recipe.size():
		curr_recipe[index] = id
		check()
		if craft_output and craft_output.has_method("update"):
			craft_output.update()
		if has_node("Label"):
			get_node("Label").text = str(curr_recipe)

func check() -> void:
	if typeof(List) != TYPE_NIL and "item" in List:
		for i in List.item:
			var item_ref = List.item[i]
			if item_ref and "recipe" in item_ref and item_ref.recipe == curr_recipe:
				if craft_output:
					craft_output.data = item_ref
					craft_output.count = 1
				return

	if craft_output:
		craft_output.data = null
		craft_output.count = 0
