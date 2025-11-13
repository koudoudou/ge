extends Animal

func _ready() -> void:
	$"State Machine/SearchFood".GoToFood.connect(setTargetNode)	

func setTargetNode(target: Node2D):

	target_node = target
	path_to_target = pathfinding_grid.get_point_path(global_position / TILE_SIZE, target_node.global_position / TILE_SIZE)
	visual_path_line2D.points = path_to_target
	velocity = Vector2.ZERO
