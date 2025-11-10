extends State
class_name SearchFood

@export var Animal: CharacterBody2D
@export var move_speed := 80.0
var target_food: Node2D

func Enter():
	target_food = find_nearest_food()
	
func Physics_Update(delta):
	if not target_food:
		Transitioned.emit(self, "Idle")
		return
		
	var direction = target_food.global_position - Animal.global_position
	if direction.length() > 40:
		Animal.velocity = direction.normalized() * move_speed
	else:
		# Pasiekė maistą — galėtum čia padidinti hunger lygį
		Animal.velocity = Vector2.ZERO
		var decision_node = Animal.get_node("PreyDecision")
		decision_node.hunger = max(decision_node.hunger - 0.7, 0)
		Transitioned.emit(self, "Idle")

func find_nearest_food():
	var foods = get_tree().get_nodes_in_group("Food")
	var nearest = null
	var min_dist = INF
	for f in foods:
		var dist = Animal.global_position.distance_to(f.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = f
	return nearest
