extends State
class_name SearchPrey

@export var Animal: CharacterBody2D
@export var move_speed := 120.0  # greičiau nei Idle
var wander_direction: Vector2
var wander_time: float = 0.0

func Enter():
	_randomize_wander()
	print("Animal looking for prey.")	

func Update(delta: float):
	if wander_time > 0:
		wander_time -= delta
	else:
		_randomize_wander()

func Physics_Update(delta: float):
	if Animal:
		Animal.velocity = wander_direction * move_speed
	
	# Patikrinam ar netoliese yra grobis
	var prey_list = get_tree().get_nodes_in_group("Prey")
	var closest = null
	var min_dist = INF
	for p in prey_list:
		var dist = Animal.global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = p
	
	if closest and min_dist < 150:  # kai artimas grobis, pereinam į Follow
		Transitioned.emit(self, "Follow")

func _randomize_wander():
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	wander_time = randf_range(1, 3)
