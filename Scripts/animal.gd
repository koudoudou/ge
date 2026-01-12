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

# --- FLOCK ---
@onready var flock_sense: Area2D = get_node_or_null("FlockSense") as Area2D

@export var flock_enabled := true
@export var flock_radius: float = 300.0
@export var separation_radius: float = 45.0

@export var w_cohesion: float = 0.35
@export var w_alignment: float = 0.25
@export var w_separation: float = 1.6

# steering cap (px/s)
@export var max_flock_force: float = 70.0

# velocity smoothing (px/s^2)
@export var accel: float = 900.0

# stabilumas su dideliu radius
@export var max_neighbors: int = 12

var _neighbors: Array[Animal] = []

# state’ai (Idle ir pan.) turi nustatyti šitą, o Animal pritaiko flock + collisions
var base_velocity: Vector2 = Vector2.ZERO

# --- PATHFINDING ---
var pathfinding_grid: AStarGrid2D = AStarGrid2D.new()
var _path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0


func _ready() -> void:
	# Leisk state machine (vaikams) suskaičiuoti base_velocity pirma
	process_physics_priority = 10

	input_pickable = true

	# Flock sense (prey tik)
	if flock_sense:
		flock_sense.body_entered.connect(_on_flock_enter)
		flock_sense.body_exited.connect(_on_flock_exit)

		# sulygina Area2D spindulį su flock_radius (jei CircleShape2D)
		if flock_sense.has_node("CollisionShape2D"):
			var cs := flock_sense.get_node("CollisionShape2D") as CollisionShape2D
			if cs and cs.shape is CircleShape2D:
				(cs.shape as CircleShape2D).radius = flock_radius

	# TileMap layers (grupės: Navigation / Obstacles)
	tilemap_layer_node = get_tree().get_nodes_in_group("Navigation")[0] as TileMapLayer
	tilemap_obstacles = get_tree().get_nodes_in_group("Obstacles")[0] as TileMapLayer

	# Build AStarGrid2D from TileMapLayer used rect.
	pathfinding_grid.region = tilemap_layer_node.get_used_rect()
	pathfinding_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	pathfinding_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinding_grid.update()

	# Viską padarom solid -> atidarom Navigation -> užsolidinam Obstacles
	pathfinding_grid.fill_solid_region(pathfinding_grid.region, true)
	for cell: Vector2i in tilemap_layer_node.get_used_cells():
		pathfinding_grid.set_point_solid(cell, false)
	for cell: Vector2i in tilemap_obstacles.get_used_cells():
		pathfinding_grid.set_point_solid(cell, true)

	call_deferred("_apply_extra_obstacles")

	# State signalai
	if is_in_group("Prey"):
		$"State Machine/SearchFood".GoToFood.connect(setTargetNode)
	$"State Machine/SearchWater".GoToWater.connect(setTargetNode)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(self)


func _physics_process(delta: float) -> void:
	# 1) Jei yra A* kelias – base_velocity perrašomas iš waypoint
	if _path_points.size() > 0 and _path_index < _path_points.size():
		var next_pos: Vector2 = _path_points[_path_index]
		var to_next := next_pos - global_position

		# Waypoint advance
		if to_next.length() <= waypoint_radius:
			_path_index += 1
			if _path_index >= _path_points.size():
				clear_target()
				base_velocity = Vector2.ZERO
			else:
				next_pos = _path_points[_path_index]
				to_next = next_pos - global_position

		if _path_index < _path_points.size() and to_next.length() > 0.001:
			base_velocity = to_next.normalized() * move_speed
		else:
			base_velocity = Vector2.ZERO

		_update_path_visual()
	# else: base_velocity palieka state machine (Idle ir t.t.)

	# 2) desired = base (+ flock)
	var desired := base_velocity
	var speed_cap := base_velocity.length()

	# flock neturi judinti, jei state’as pats stovi (speed_cap ~ 0)
	if flock_enabled and is_in_group("Prey") and speed_cap > 0.001:
		# mažinam flock prie waypoint, kad nenutrauktų kelio
		var t := 1.0
		if _path_points.size() > 0 and _path_index < _path_points.size():
			var d := global_position.distance_to(_path_points[_path_index])
			t = clampf(d / 40.0, 0.0, 1.0)

		var steer := _flock_steer()

		# jei Idle greitis mažas, o move_speed property didelis (80),
		# sumažinam steer proporcingai, kad flock neperimtų valdymo
		if move_speed > 0.001:
			steer *= speed_cap / move_speed

		desired += steer * t

	# 3) niekada neleisk viršyti state’o greičio (Idle 15 turi likti 15)
	if speed_cap > 0.001 and desired.length() > speed_cap:
		desired = desired.normalized() * speed_cap

	# 4) smooth – mažina jitter
	velocity = velocity.move_toward(desired, accel * delta)
	move_and_slide()


# -------------------------
# FLOCK
# -------------------------

func _on_flock_enter(b: Node) -> void:
	if not is_in_group("Prey"):
		return
	if b is Animal and b != self and b.is_in_group("Prey"):
		if not _neighbors.has(b):
			_neighbors.append(b)

func _on_flock_exit(b: Node) -> void:
	if b is Animal:
		_neighbors.erase(b)

func _flock_steer() -> Vector2:
	if not flock_enabled or not is_in_group("Prey"):
		return Vector2.ZERO
	if _neighbors.is_empty():
		return Vector2.ZERO

	# prune invalid
	for i in range(_neighbors.size() - 1, -1, -1):
		if not is_instance_valid(_neighbors[i]):
			_neighbors.remove_at(i)

	var pos := global_position

	# Kandidatai: [dist, Animal]
	var candidates: Array = []
	for n in _neighbors:
		if not is_instance_valid(n):
			continue
		var d: float = pos.distance_to(n.global_position)
		if d > 0.001 and d <= flock_radius:
			candidates.append([d, n])

	if candidates.is_empty():
		return Vector2.ZERO

	# Tik artimiausi (stabilumas)
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	if candidates.size() > max_neighbors:
		candidates.resize(max_neighbors)

	var center := Vector2.ZERO
	var avg_vel := Vector2.ZERO
	var sep := Vector2.ZERO
	var count := 0

	for item in candidates:
		var d: float = item[0]
		var n: Animal = item[1]
		center += n.global_position
		avg_vel += n.velocity
		count += 1

		if d < separation_radius:
			# inverse-square separation (stiprus tik labai arti)
			sep += (pos - n.global_position) / maxf(d * d, 1.0)

	center /= float(count)
	avg_vel /= float(count)

	var cohesion_dir := center - pos
	cohesion_dir = cohesion_dir.normalized() if cohesion_dir.length() > 0.001 else Vector2.ZERO

	var alignment_dir := avg_vel
	alignment_dir = alignment_dir.normalized() if alignment_dir.length() > 0.001 else Vector2.ZERO

	var separation_dir := sep
	separation_dir = separation_dir.normalized() if separation_dir.length() > 0.001 else Vector2.ZERO

	var steer := (cohesion_dir * w_cohesion +
		alignment_dir * w_alignment +
		separation_dir * w_separation)

	# paverčiam į px/s ir užcapinam
	steer *= move_speed
	return steer.limit_length(max_flock_force)


func get_flock_status() -> String:
	if not is_in_group("Prey"):
		return "N/A"

	var count := 0
	for n in _neighbors:
		if is_instance_valid(n) and n != self and n.is_in_group("Prey"):
			if global_position.distance_to(n.global_position) <= flock_radius:
				count += 1

	return "Flocked" if count > 0 else "Alone"


# -------------------------
# TARGET / PATH
# -------------------------

func setTargetNode(target: Node2D) -> void:
	target_node = target
	_rebuild_path()

# (jei turi seną connection Animal.tscn)
func _on_search_food_go_to_food(target: Node2D) -> void:
	setTargetNode(target)

func clear_target() -> void:
	target_node = null
	_path_points = PackedVector2Array()
	_path_index = 0
	base_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	if visual_path_line2D:
		visual_path_line2D.points = PackedVector2Array()

func _rebuild_path() -> void:
	_path_points = PackedVector2Array()
	_path_index = 0

	if not target_node or not tilemap_layer_node:
		clear_target()
		return

	var start_cell: Vector2i = tilemap_layer_node.local_to_map(tilemap_layer_node.to_local(global_position))
	var goal_cell: Vector2i = tilemap_layer_node.local_to_map(tilemap_layer_node.to_local(target_node.global_position))

	if not pathfinding_grid.is_in_boundsv(start_cell) or not pathfinding_grid.is_in_boundsv(goal_cell):
		clear_target()
		return

	var cell_path: Array[Vector2i] = pathfinding_grid.get_id_path(start_cell, goal_cell, true)
	if cell_path.size() <= 1:
		clear_target()
		return

	for cell: Vector2i in cell_path:
		var local_center: Vector2 = tilemap_layer_node.map_to_local(cell)
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
# Extra obstacles (Food/Water kaip solid A*)
# -------------------------

func _apply_extra_obstacles() -> void:
	for g in extra_obstacle_groups:
		for n in get_tree().get_nodes_in_group(g):
			if n == null or not is_instance_valid(n):
				continue
			if n == self:
				continue
			_mark_node_as_obstacle(n)

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
		minv.x = minf(minv.x, w.x)
		minv.y = minf(minv.y, w.y)
		maxv.x = maxf(maxv.x, w.x)
		maxv.y = maxf(maxv.y, w.y)

	return Rect2(minv, maxv - minv)

func _mark_node_as_obstacle(node: Node) -> void:
	if not (node is Node2D):
		return

	var rect := _get_node_global_aabb(node)

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


# -------------------------
# UI getters
# -------------------------

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
