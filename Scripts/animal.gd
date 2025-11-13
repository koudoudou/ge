extends CharacterBody2D
class_name Animal
const TILE_SIZE = 16
const TURNS_TO_MOVE: int = 2

var tilemap_layer_node: TileMapLayer = null
var tilemap_obstacles: TileMapLayer = null
var target_node: Node2D = null
@export var visual_path_line2D: Line2D = null

var pathfinding_grid: AStarGrid2D = AStarGrid2D.new()
var path_to_target: Array = []
var turn_counter: int = 1
var timer:= 0.0

func _ready() -> void:
	tilemap_layer_node = get_tree().get_nodes_in_group("Navigation")[0]
	tilemap_obstacles = get_tree().get_nodes_in_group("Obstacles")[0]
	visual_path_line2D.global_position = Vector2(TILE_SIZE/2.0,TILE_SIZE/2.0)
	

	
	pathfinding_grid.region = tilemap_layer_node.get_used_rect()
	pathfinding_grid.cell_size = Vector2(TILE_SIZE,TILE_SIZE)
	pathfinding_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	pathfinding_grid.update()
	
	for cell in tilemap_layer_node.get_used_cells():
		pathfinding_grid.set_point_solid(cell, false)
	for cell in tilemap_obstacles.get_used_cells():
		pathfinding_grid.set_point_solid(cell, true)
	if self.is_in_group("Prey"):		
		$"State Machine/SearchFood".GoToFood.connect(setTargetNode)
	$"State Machine/SearchWater".GoToWater.connect(setTargetNode)
func _move_ai():


	if path_to_target.size() > 1:
		path_to_target.remove_at(0)
		var go_to_pos: Vector2 = path_to_target[0] + Vector2(TILE_SIZE/2.0, TILE_SIZE/2.0)
		
		global_position = go_to_pos
		
		visual_path_line2D.points = path_to_target
	else:
		target_node = null		
			
func setTargetNode(target: Node2D):

	target_node = target
	path_to_target = pathfinding_grid.get_point_path(global_position / TILE_SIZE, target_node.global_position / TILE_SIZE)
	visual_path_line2D.points = path_to_target
	velocity = Vector2.ZERO
	

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		if target_node:
			_move_ai()
			timer = 0.5
		else:
			move_and_slide()
	#move_and_slide()		
	#if target_node:
		#_move_ai()
		#timer = 1.0
	#else:
		#move_and_slide()
