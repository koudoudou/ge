extends State
class_name SearchWater

@export var Animal: Animal
@export var move_speed := 80.0

var target_water: Node2D
signal GoToWater(target: Node2D)

func Enter():
	if Animal:
		Animal.move_speed = move_speed
	target_water = find_nearest_water()
	emit_signal("GoToWater", target_water)

func Exit():
	if Animal:
		Animal.clear_target()

func Physics_Update(_delta):
	if not target_water or not is_instance_valid(target_water):
		if Animal:
			Animal.clear_target()
		Transitioned.emit(self, "Idle")
		return

	# Movement is handled by Animal via A* path.
	var dist := Animal.global_position.distance_to(target_water.global_position)
	if Animal.target_node == null and dist > 40.0:
		Transitioned.emit(self, "Idle")
		return
	if dist <= 40.0:
		Animal.velocity = Vector2.ZERO
		Animal.clear_target()

		if Animal.is_in_group("Prey"):
			var decision_node = Animal.get_node("PreyDecision")
			decision_node.thirst = max(decision_node.thirst - 0.7, 0)
			Transitioned.emit(self, "Idle")
		elif Animal.is_in_group("Predator"):
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
