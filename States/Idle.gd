extends State
class_name Idle

@export var Animal: Animal
@export var move_speed := 15.0

var move_direction: Vector2
var wander_time: float

func randomize_wander():
	move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	wander_time = randf_range(1, 5)

func Enter():
	randomize_wander()

func Update(delta: float):
	wander_time -= delta
	if wander_time <= 0.0:
		randomize_wander()

func Physics_Update(_delta: float):
	if Animal:
		Animal.base_velocity = move_direction * move_speed
