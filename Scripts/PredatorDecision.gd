extends AnimalDecisionBase
class_name PredatorDecision

@export var hunt_radius := 520.0

var bloodlust := 0.0

func _process(delta: float):
	if is_dead:
		return

	hunger = clamp(hunger + hunger_rate * delta, 0.0, 1.0)
	thirst = clamp(thirst + thirst_rate * delta, 0.0, 1.0)
	check_for_prey(delta)

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

	var hunt_val = clamp(bloodlust + hunger * 0.6, 0.0, 1.0)
	var water_val = thirst
	var idle_val = 1.0 - max(hunt_val, water_val)

	var exp_vals = [exp(hunt_val), exp(water_val), exp(idle_val), bloodlust]
	var total = exp_vals.reduce(func(a, b): return a + b)
	var probs = exp_vals.map(func(v): return v / total)

	var names = ["SearchPrey", "SearchWater", "Idle", "Follow"]
	var next_state = names[probs.find(probs.max())]

	if current_name != next_state.to_lower():
		state_machine.on_child_transition(current, next_state)
		print(state_machine.current_state)

func check_for_prey(delta: float) -> void:
	var prey_detected := 0.0	
	var prey = get_tree().get_nodes_in_group("Prey")
	for p in prey:
		prey_detected = 1.0 - (animal.global_position.distance_to(p.global_position) / hunt_radius) # arčiau – stipresnė reakcija
		break
	# Smooth transition tarp 0 ir prey_detected
	var lerp_speed := 2.0
	bloodlust = lerp(bloodlust, prey_detected, delta * lerp_speed)
