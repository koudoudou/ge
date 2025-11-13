extends AnimalDecision
class_name PredatorDecision

@export var hunt_radius := 520.0

var bloodlust := 0.0
var prey_detected := 0.0

func _process(delta: float):
	if hunger >= 1.0 or thirst >= 1.0:
		var current = state_machine.current_state		
		state_machine.on_child_transition(current,"Dead")
		return

	hunger = clamp(hunger + hunger_rate * delta, 0.0, 1.0)
	thirst = clamp(thirst + thirst_rate * delta, 0.0, 1.0)
	
	_decay_needs(delta)

	decision_timer -= delta
	if decision_timer <= 0:
		make_fuzzy_decision()
		decision_timer = 1.0



func make_fuzzy_decision():
	var current = state_machine.current_state
	var current_name = current.name.to_lower() if current else ""
	
	var hunt_val = check_for_prey()
	
	var hunger_val = clamp(hunger * 0.6, 0.0, 1.0)
	var water_val = thirst
	var idle_val = 1.0 - max(hunger_val, water_val)

	var exp_vals = [exp(hunger_val), exp(water_val), exp(idle_val), exp(hunt_val)]
	var total = exp_vals.reduce(func(a, b): return a + b)
	var probs = exp_vals.map(func(v): return v / total)

	var names = ["searchprey", "searchwater", "idle", "follow"]
	var next_state = names[probs.find(probs.max())]

	if current_name != next_state.to_lower():
		state_machine.on_child_transition(current, next_state)
		print(state_machine.current_state)

func check_for_prey() -> float:
	
	var prey = get_tree().get_nodes_in_group("Prey")
	for p in prey:
		if animal.global_position.distance_to(p.global_position) < hunt_radius:
			return 1.0
	return 0.0
