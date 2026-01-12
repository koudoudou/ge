extends State
class_name SearchFood

@export var Animal: Animal
@export var move_speed := 80.0

var target_food: Node2D
signal GoToFood(target: Node2D)

func Enter():
	if Animal:
		Animal.move_speed = move_speed
	target_food = find_nearest_food()
	emit_signal("GoToFood", target_food)

func Exit():
	# If we leave this state for any reason (e.g. danger -> Flee), stop following the old path.
	if Animal:
		Animal.clear_target()

func Physics_Update(_delta):
	if not target_food or not is_instance_valid(target_food):
		if Animal:
			Animal.clear_target()
		Transitioned.emit(self, "Idle")
		return

	# Movement is handled by Animal via A* path.
	var dist := Animal.global_position.distance_to(target_food.global_position)
	if Animal.target_node == null and dist > 40.0:
		Transitioned.emit(self, "Idle")
		return
	if dist <= 40.0:
		# Pasiekė maistą
		Animal.base_velocity = Vector2.ZERO
		Animal.clear_target()
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
