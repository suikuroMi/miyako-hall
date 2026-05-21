extends Control

@onready var craft_slots: GridContainer = get_node("CraftingSlots")
@onready var craft_output: Button = get_node("Output")

@export var curr_recipe: Array[String] = ["", "", "", "", "", "", "", "", ""]

func _ready() -> void:
	# Technical Purity: Ensure the array is exactly the size of the slot count
	if curr_recipe.size() != craft_slots.get_child_count():
		curr_recipe.resize(craft_slots.get_child_count())
		curr_recipe.fill("")
		
	for i in craft_slots.get_child_count():
		craft_slots.get_child(i).craft_index = i

func update_recipe(index: int, id: String):
	if index >= 0 and index < curr_recipe.size():
		curr_recipe[index] = id
		check()
		if craft_output:
			craft_output.update()

func check():
	for i in List.item:
		var item_ref = List.item[i]
		if item_ref.recipe and item_ref.recipe == curr_recipe:
			craft_output.data = item_ref
			craft_output.count = 1
			return
	
	if craft_output:
		craft_output.data = null
		craft_output.count = 0

func _physics_process(_delta: float) -> void:
	if has_node("Label"):
		get_node("Label").text = str(curr_recipe)
