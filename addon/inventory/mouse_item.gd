extends TextureRect

@export var data: Item
@export var count: int
@onready var count_label: Label = get_node("Count")

func _physics_process(_delta: float) -> void:
	if count <= 0:
		data = null
	count_label.text = str(count)
	count_label.visible = count > 1
	if data:
		self.texture = data.texture
	else:
		self.texture = null