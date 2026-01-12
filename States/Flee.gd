extends State
class_name Flee

@export var Animal: CharacterBody2D
@export var move_speed := 100.0
var danger_target: Node2D

func Enter():
	danger_target = find_nearest_predator()

func Physics_Update(delta):
	if not danger_target:
		Transitioned.emit(self, "Idle")
		return

	var direction = Animal.global_position - danger_target.global_position
	
	if direction.length() < 300:
		Animal.base_velocity = direction.normalized() * move_speed
	else:
		# Kai pavojus toli – grįžtam į Idle
		Transitioned.emit(self, "Idle")
		Animal.base_velocity = Vector2.ZERO

func find_nearest_predator():
	var predators = get_tree().get_nodes_in_group("Predator")
	var nearest = null
	var min_dist = INF
	for p in predators:
		var dist = Animal.global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = p
	return nearest
