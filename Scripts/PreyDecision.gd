extends AnimalDecisionBase
class_name PreyDecision

@export var danger_radius := 200.0

var danger := 0.0
func _process(delta: float):
	if is_dead:
		return
		
	hunger = clamp(hunger + hunger_rate * delta, 0.0, 1.0)
	thirst = clamp(thirst + thirst_rate * delta, 0.0, 1.0)	

	_decay_needs(delta)
		
	decision_timer -= delta
	if decision_timer <= 0:
		make_fuzzy_decision()
		decision_timer = 1.0	
		
	if hunger >= 1.0 or thirst >= 1.0:
		die()
		
func make_fuzzy_decision():
	var current = state_machine.current_state
	var current_name = current.name.to_lower() if current else ""

	danger = check_for_predators()

	var flee_val = danger
	var food_val = hunger
	var water_val = thirst
	var idle_val = 1.0 - max(flee_val, food_val, water_val)

	var exp_vals = [exp(flee_val), exp(food_val), exp(water_val), exp(idle_val)]
	var total = exp_vals.reduce(func(a, b): return a + b)
	var probs = exp_vals.map(func(v): return v / total)

	var names = ["Flee", "SearchFood", "SearchWater", "Idle"]
	var next_state = names[probs.find(probs.max())]

	if current_name != next_state.to_lower():
		state_machine.on_child_transition(current, next_state)

func check_for_predators() -> float:
	var predators = get_tree().get_nodes_in_group("Predator")
	for p in predators:
		if animal.global_position.distance_to(p.global_position) < danger_radius:
			return 1.0
	return 0.0
