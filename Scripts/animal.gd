extends CharacterBody2D
class_name Animal

const TILE_SIZE := 16

var tilemap_layer_node: TileMapLayer
var tilemap_obstacles: TileMapLayer
var target_node: Node2D

signal selected(animal: Animal)

@export var visual_path_line2D: Line2D
@export var move_speed: float = 80.0
@export var waypoint_radius: float = 6.0
@export var extra_obstacle_groups: Array[StringName] = ["Food", "Water"]

var pathfinding_grid: AStarGrid2D = AStarGrid2D.new()

var _path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0


func _ready() -> void:
	input_pickable = true
	# TileMap layers (world is using TileMapLayer nodes grouped as Navigation / Obstacles)
	tilemap_layer_node = get_tree().get_nodes_in_group("Navigation")[0]
	tilemap_obstacles = get_tree().get_nodes_in_group("Obstacles")[0]

	# Build AStarGrid2D from TileMapLayer used rect.
	pathfinding_grid.region = tilemap_layer_node.get_used_rect()
	pathfinding_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	pathfinding_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinding_grid.update()

	# By default all points are walkable, so make everything solid first,
	# then enable only the Navigation cells, then re-solid Obstacles.
	pathfinding_grid.fill_solid_region(pathfinding_grid.region, true)
	for cell: Vector2i in tilemap_layer_node.get_used_cells():
		pathfinding_grid.set_point_solid(cell, false)
	for cell: Vector2i in tilemap_obstacles.get_used_cells():
		pathfinding_grid.set_point_solid(cell, true)

	# IMPORTANT: call after you finish solid/walkable setup, otherwise you overwrite it.
	call_deferred("_apply_extra_obstacles")

	if is_in_group("Prey"):
		$"State Machine/SearchFood".GoToFood.connect(setTargetNode)
	$"State Machine/SearchWater".GoToWater.connect(setTargetNode)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)
		
func _physics_process(delta: float) -> void:
	# If we have a path, we override velocity and move smoothly along waypoints.
	if _path_points.size() > 0 and _path_index < _path_points.size():
		var next_pos: Vector2 = _path_points[_path_index]
		var to_next := next_pos - global_position

		# Advance waypoint when close enough.
		if to_next.length() <= waypoint_radius:
			_path_index += 1
			if _path_index >= _path_points.size():
				# Path finished.
				clear_target()
				velocity = Vector2.ZERO
				move_and_slide()
				return
			next_pos = _path_points[_path_index]
			to_next = next_pos - global_position

		if to_next.length() > 0.001:
			velocity = to_next.normalized() * move_speed
		else:
			velocity = Vector2.ZERO

		_update_path_visual()

	move_and_slide()


func setTargetNode(target: Node2D) -> void:
	target_node = target
	_rebuild_path()


# For the connection in Animal.tscn (safe even if you later remove the connection).
func _on_search_food_go_to_food(target: Node2D) -> void:
	setTargetNode(target)


func clear_target() -> void:
	target_node = null
	_path_points = PackedVector2Array()
	_path_index = 0
	if visual_path_line2D:
		visual_path_line2D.points = PackedVector2Array()


func _rebuild_path() -> void:
	_path_points = PackedVector2Array()
	_path_index = 0

	if not target_node or not tilemap_layer_node:
		clear_target()
		return

	# Convert global positions to map cell coordinates correctly (global -> local -> map).
	var start_cell: Vector2i = tilemap_layer_node.local_to_map(tilemap_layer_node.to_local(global_position))
	var goal_cell: Vector2i = tilemap_layer_node.local_to_map(tilemap_layer_node.to_local(target_node.global_position))

	if not pathfinding_grid.is_in_boundsv(start_cell) or not pathfinding_grid.is_in_boundsv(goal_cell):
		clear_target()
		return

	# allow_partial_path = true so the agent still gets a reasonable path if the target cell is solid.
	var cell_path: Array[Vector2i] = pathfinding_grid.get_id_path(start_cell, goal_cell, true)
	if cell_path.size() <= 1:
		clear_target()
		return

	for cell: Vector2i in cell_path:
		var local_center: Vector2 = tilemap_layer_node.map_to_local(cell) # centered local position
		_path_points.append(tilemap_layer_node.to_global(local_center))

	_update_path_visual()


func _update_path_visual() -> void:
	if not visual_path_line2D:
		return

	var pts := PackedVector2Array()
	pts.append(global_position)
	for i in range(_path_index, _path_points.size()):
		pts.append(_path_points[i])
	visual_path_line2D.points = pts


# -------------------------
# Extra obstacles (Food/Water as solid cells for AStarGrid2D)
# -------------------------

func _apply_extra_obstacles() -> void:
	# Mark cells covered by nodes in these groups as solid.
	for g in extra_obstacle_groups:
		for n in get_tree().get_nodes_in_group(g):
			if n == null or not is_instance_valid(n):
				continue
			if n == self:
				continue
			_mark_node_as_obstacle(n)

	# If target already set, rebuild path to reflect new solids.
	if target_node:
		_rebuild_path()


func _cell_in_region(c: Vector2i) -> bool:
	return pathfinding_grid.region.has_point(c)


func _find_collision_shape(node: Node) -> CollisionShape2D:
	if node is CollisionShape2D:
		return node
	for ch in node.get_children():
		var found := _find_collision_shape(ch)
		if found != null:
			return found
	return null


func _get_node_global_aabb(node: Node) -> Rect2:
	var cs := _find_collision_shape(node)
	if cs == null or cs.shape == null:
		if node is Node2D:
			return Rect2((node as Node2D).global_position, Vector2.ZERO)
		return Rect2()

	# Shape2D.get_rect() returns a local-space bounding rect around (0,0).
	var local_rect: Rect2 = cs.shape.get_rect()
	var t := cs.global_transform

	var corners := PackedVector2Array([
		local_rect.position,
		local_rect.position + Vector2(local_rect.size.x, 0),
		local_rect.position + Vector2(0, local_rect.size.y),
		local_rect.position + local_rect.size
	])

	var minv := Vector2(INF, INF)
	var maxv := Vector2(-INF, -INF)

	for c in corners:
		var w := t * c
		minv.x = min(minv.x, w.x)
		minv.y = min(minv.y, w.y)
		maxv.x = max(maxv.x, w.x)
		maxv.y = max(maxv.y, w.y)

	return Rect2(minv, maxv - minv)


func _mark_node_as_obstacle(node: Node) -> void:
	if not (node is Node2D):
		return

	var rect := _get_node_global_aabb(node)

	# Fallback: mark just the cell under the node.
	if rect.size == Vector2.ZERO:
		var c := tilemap_layer_node.local_to_map(tilemap_layer_node.to_local((node as Node2D).global_position))
		if _cell_in_region(c):
			pathfinding_grid.set_point_solid(c, true)
		return

	var p0 := rect.position
	var p1 := rect.position + rect.size

	var cmin := tilemap_layer_node.local_to_map(tilemap_layer_node.to_local(p0))
	var cmax := tilemap_layer_node.local_to_map(tilemap_layer_node.to_local(p1))

	var xmin: int = mini(cmin.x, cmax.x)
	var xmax: int = maxi(cmin.x, cmax.x)
	var ymin: int = mini(cmin.y, cmax.y)
	var ymax: int = maxi(cmin.y, cmax.y)

	for y in range(ymin, ymax + 1):
		for x in range(xmin, xmax + 1):
			var cell := Vector2i(x, y)
			if _cell_in_region(cell):
				pathfinding_grid.set_point_solid(cell, true)

func get_state_name() -> String:
	if has_node("State Machine"):
		var sm := $"State Machine"
		var cs = sm.get("current_state")
		if cs != null:
			return str(cs.name)
	return "Unknown"


func _get_decision_node() -> Node:
	if has_node("PreyDecision"):
		return $PreyDecision
	if has_node("PredatorDecision"):
		return $PredatorDecision
	# fallback: first child with hunger/thirst vars
	for ch in get_children():
		if ch != null and (ch.get("hunger") != null or ch.get("thirst") != null):
			return ch
	return null


func get_hunger_01() -> float:
	var d := _get_decision_node()
	if d == null:
		return 0.0
	var v = d.get("hunger")
	return float(v) if v != null else 0.0


func get_thirst_01() -> float:
	var d := _get_decision_node()
	if d == null:
		return 0.0
	var v = d.get("thirst")
	return float(v) if v != null else 0.0
