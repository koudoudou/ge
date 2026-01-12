extends Node2D

@onready var animal_ui: CanvasLayer = $AnimalUi
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for a in get_tree().get_nodes_in_group("Prey"):
		a.selected.connect(_on_animal_selected)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _on_animal_selected(a: Animal) -> void:
	animal_ui.show_animal(a)
