extends State
class_name SearchWater

@export var Animal: CharacterBody2D
@export var move_speed := 80.0
var target_water: Node2D
signal GoToWater(target: Node2D)

func Enter():
	target_water = find_nearest_water()
	emit_signal("GoToWater",target_water)


func Physics_Update(delta):
	if not target_water:
		Transitioned.emit(self, "Idle")
		return
		
	var direction = target_water.global_position - Animal.global_position
	if direction.length() > 40:
		Animal.velocity = direction.normalized() * move_speed
	else:
		Animal.velocity = Vector2.ZERO
		if Animal.is_in_group("Prey"):
			var decision_node = Animal.get_node("PreyDecision")
			decision_node.thirst = max(decision_node.thirst - 0.7, 0)
			Transitioned.emit(self, "Idle")
		if Animal.is_in_group("Predator"):
			var decision_node = Animal.get_node("PredatorDecision")
			decision_node.thirst = max(decision_node.thirst - 0.7, 0)
			Transitioned.emit(self, "Idle")

func find_nearest_water():
	var waters = get_tree().get_nodes_in_group("Water")
	var nearest = null
	var min_dist = INF
	for w in waters:
		var dist = Animal.global_position.distance_to(w.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = w
	return nearest
