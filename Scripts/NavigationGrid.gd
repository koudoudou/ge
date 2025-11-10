extends Node2D
class_name NavigationGrid


@export var cell_size := Vector2i(36, 36)    # vieno cell dydis px
@export var debug_draw := true               # ar piešti grid vizualiai

var astar := AStarGrid2D.new()
var world_size := Vector2(1152, 648)        # tavo scena / pasaulio dydis
var grid_size := Vector2i()                 # grid dydis apskaičiuojamas pagal pasaulio dydį

func _ready():
	# 1️⃣ Apskaičiuojame grid size pagal pasaulio dydį ir cell_size
	grid_size = Vector2i(ceil(world_size.x / cell_size.x), ceil(world_size.y / cell_size.y))

	# 2️⃣ Nustatome AStarGrid2D region ir cell_size
	astar.cell_size = cell_size
	astar.region = Rect2i(Vector2i.ZERO, grid_size)
	astar.set_default_compute_heuristic(AStarGrid2D.HEURISTIC_MANHATTAN)
	astar.set_diagonal_mode(AStarGrid2D.DIAGONAL_MODE_ALWAYS)
	astar.update()

	print("✅ AStarGrid initialized: ", grid_size, " cells of size ", cell_size)

# ----------------------------------------------
# Konversijos metodai
# ----------------------------------------------

# Pasaulio koordinatės → tinklelio cell koordinatės
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		clamp(floor(world_pos.x / cell_size.x), 0, grid_size.x - 1),
		clamp(floor(world_pos.y / cell_size.y), 0, grid_size.y - 1)
	)

# Cell koordinatės → pasaulio koordinatės (cell centro taškas)
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * cell_size.x + cell_size.x * 0.5,
		cell.y * cell_size.y + cell_size.y * 0.5
	)

# Pažymėti cell kaip užblokuotą
func block_cell(world_pos: Vector2):
	var cell = world_to_cell(world_pos)
	if astar.is_in_boundsv(cell):
		astar.set_point_solid(cell, true)

# Atblokuoti cell
func unblock_cell(world_pos: Vector2):
	var cell = world_to_cell(world_pos)
	if astar.is_in_boundsv(cell):
		astar.set_point_solid(cell, false)

# Gauti A* kelią tarp dviejų pasaulio pozicijų
func get_astar_path(start_pos: Vector2, end_pos: Vector2) -> Array[Vector2]:
	var start_cell = world_to_cell(start_pos)
	var end_cell = world_to_cell(end_pos)

	if not astar.is_in_boundsv(start_cell) or not astar.is_in_boundsv(end_cell):
		return Array()  # tuščias kelias

	var path_cells = astar.get_point_path(start_cell, end_cell)
	var world_path: Array[Vector2] = []
	for c in path_cells:
		world_path.append(cell_to_world(c))
	return world_path

# ----------------------------------------------
# Debug piešimas
# ----------------------------------------------
func _draw():
	if not debug_draw:
		return

	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var cell = Vector2i(x, y)
			var pos = cell_to_world(cell)
			draw_rect(Rect2(pos - cell_size * 0.5, cell_size), Color(0, 1, 0, 0.1))
