extends State
class_name Dead

@export var Animal: CharacterBody2D
@export var move_speed := 0.0

	
func Enter():
	var tween = create_tween()
	tween.tween_property(Animal, "modulate", Color(1, 0, 0), 0.5)
	
	
		
func Physics_Update(delta: float):
	if Animal:
		Animal.velocity = Vector2.ZERO
