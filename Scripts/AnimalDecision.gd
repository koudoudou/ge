extends Node
class_name AnimalDecision

@export var animal: CharacterBody2D
@export var state_machine: Node
@export var hunger_rate := 0.02
@export var thirst_rate := 0.03
@export var smooth_decay := 0.05

var hunger := 0.0
var thirst := 0.0
var decision_timer := 0.0
		

func _decay_needs(delta: float) -> void:
	if not state_machine or not state_machine.current_state:
		return
	var name = state_machine.current_state.name.to_lower()
	if name == "searchfood":
		hunger = max(hunger - smooth_decay * delta, 0.0)
	elif name == "searchwater":
		thirst = max(thirst - smooth_decay * delta, 0.0)
	elif name == "searchprey":
		hunger = max(hunger - smooth_decay * delta * 0.5, 0.0)
