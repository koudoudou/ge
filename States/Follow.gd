extends State
class_name Follow

@export var Animal: CharacterBody2D
@export var move_speed := 150.0
var prey_target: Node2D
var decision_timer := 1.0

func Enter():
	prey_target = find_nearest_prey()

func Physics_Update(delta):
	if not prey_target:
		Transitioned.emit(self, "Idle")
		return

	var direction = prey_target.global_position - Animal.global_position
	
	# Jei grobis dar netoli – tęsiame gaudymą
	if direction.length() > 50:
		Animal.velocity = direction.normalized() * move_speed
	else:
		# Pagavo grobį
		Animal.velocity = Vector2.ZERO
		var decision_node = Animal.get_node("PredatorDecision")
		decision_node.hunger = 0.0
		
		decision_timer -= delta
		if decision_timer <= 0:
			decision_timer = 1.0		
			if prey_target:
				prey_target.queue_free()
		
		# Grįžtam į poilsio būseną
			Transitioned.emit(self, "Idle")

func find_nearest_prey():
	var preys = get_tree().get_nodes_in_group("Prey")
	var nearest = null
	var min_dist = INF
	for p in preys:
		var dist = Animal.global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = p
	return nearest
