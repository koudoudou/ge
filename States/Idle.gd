extends State
class_name Idle

@export var Animal: CharacterBody2D
@export var move_speed := 15.0

var player: CharacterBody2D

var move_direction : Vector2
var wawnder_time: float

func randomize_wander():
	move_direction = Vector2(randf_range(-2,2),randf_range(-2,2)).normalized()
	wawnder_time = randf_range(1,5)
	
func Enter():
	randomize_wander()
	
func Update(delta: float):
	if wawnder_time > 0:
		wawnder_time -=delta
		
	else:
		randomize_wander()
		
func Physics_Update(delta: float):
	if Animal:
		Animal.velocity = move_direction * move_speed
		
	
