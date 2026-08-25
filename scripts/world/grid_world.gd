extends Node3D

signal player_moved(new_position: Vector2i)
signal player_turned(new_facing: int)

const CELL_SIZE: float = 2.0

enum Facing { NORTH, EAST, SOUTH, WEST }

var grid_data: Array[Array] = []
var grid_width: int = 0
var grid_height: int = 0
var player_grid_pos: Vector2i = Vector2i.ZERO
var player_facing: int = Facing.NORTH

@onready var camera: Camera3D = $Camera3D
@onready var grid_mesh: MeshInstance3D = $FloorMesh

func _ready() -> void:
	_build_test_dungeon()
	_place_player_at_start()
	_update_camera()

func _build_test_dungeon() -> void:
	grid_width = 8
	grid_height = 8
	grid_data.clear()
	for y in range(grid_height):
		var row: Array = []
		for x in range(grid_width):
			if x == 0 or x == grid_width - 1 or y == 0 or y == grid_height - 1:
				row.append(1)
			else:
				row.append(0)
		grid_data.append(row)
	grid_data[3][3] = 1
	grid_data[3][4] = 1
	grid_data[4][3] = 1
	_build_grid_mesh()

const CELLS_TO_KEEP := ["Camera3D", "WorldEnvironment", "DirectionalLight3D", "OmniLight3D", "FloorMesh"]

func _build_grid_mesh() -> void:
	for child in get_children():
		if child.name in CELLS_TO_KEEP:
			continue
		child.queue_free()
	var wall_scene: PackedScene = load("res://scenes/world/wall_tile.tscn")
	var floor_scene: PackedScene = load("res://scenes/world/floor_tile.tscn")
	for y in range(grid_height):
		for x in range(grid_width):
			var cell: int = grid_data[y][x]
			var pos := Vector3(x * CELL_SIZE, 0.0, y * CELL_SIZE)
			if cell == 1:
				var wall := wall_scene.instantiate()
				wall.position = pos + Vector3(0.0, CELL_SIZE * 0.5, 0.0)
				add_child(wall)
			else:
				var floor_tile := floor_scene.instantiate()
				floor_tile.position = pos
				add_child(floor_tile)

func _place_player_at_start() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			if grid_data[y][x] == 0:
				player_grid_pos = Vector2i(x, y)
				return
	player_grid_pos = Vector2i(1, 1)

func _update_camera() -> void:
	var target_pos := Vector3(
		player_grid_pos.x * CELL_SIZE,
		CELL_SIZE * 0.8,
		player_grid_pos.y * CELL_SIZE
	)
	camera.position = target_pos
	var target_rotation: float = 0.0
	match player_facing:
		Facing.NORTH:
			target_rotation = 0.0
		Facing.EAST:
			target_rotation = -PI / 2.0
		Facing.SOUTH:
			target_rotation = PI
		Facing.WEST:
			target_rotation = PI / 2.0
	camera.rotation.y = target_rotation

func is_walkable(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= grid_width:
		return false
	if grid_pos.y < 0 or grid_pos.y >= grid_height:
		return false
	return grid_data[grid_pos.y][grid_pos.x] == 0

func get_forward_pos() -> Vector2i:
	var offset: Vector2i
	match player_facing:
		Facing.NORTH:
			offset = Vector2i(0, -1)
		Facing.SOUTH:
			offset = Vector2i(0, 1)
		Facing.EAST:
			offset = Vector2i(1, 0)
		Facing.WEST:
			offset = Vector2i(-1, 0)
	return player_grid_pos + offset

func try_move(_actor_index: int, direction: Vector2i) -> bool:
	var target_pos := player_grid_pos + direction
	if not is_walkable(target_pos):
		return false
	player_grid_pos = target_pos
	_update_camera()
	player_moved.emit(player_grid_pos)
	return true

func try_turn(_actor_index: int, turn_dir: int) -> bool:
	player_facing = posmod(player_facing + turn_dir, 4)
	_update_camera()
	player_turned.emit(player_facing)
	return true

func get_cell(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= grid_width:
		return 1
	if grid_pos.y < 0 or grid_pos.y >= grid_height:
		return 1
	return grid_data[grid_pos.y][grid_pos.x]
