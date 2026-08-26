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

var _dynamic_children: Array[Node] = []

func _ready() -> void:
	if GameManager.party.size() > 0:
		_load_dungeon_for_game()
	else:
		GameManager.party_changed.connect(_load_dungeon_for_game, CONNECT_ONE_SHOT)

func _load_dungeon_for_game() -> void:
	if GameManager.current_dungeon_id.is_empty():
		DebugLog.warn("GridWorld: No dungeon ID set, using default grid")
		_build_default_grid()
		return
	load_dungeon(GameManager.current_dungeon_id, GameManager.current_floor)

func load_dungeon(dungeon_id: String, floor: int) -> void:
	var dungeon_record: Dictionary = DataRegistry.get_record(dungeon_id)
	if dungeon_record.is_empty():
		DebugLog.warn("GridWorld: Dungeon record not found: %s" % dungeon_id)
		_build_default_grid()
		return
	var floor_data: Variant = dungeon_record.get("floor_data")
	if not floor_data is Array:
		DebugLog.data_issue(dungeon_id, "floor_data", "Array", type_string(typeof(floor_data)))
		_build_default_grid()
		return
	if floor < 1 or floor > floor_data.size():
		DebugLog.warn("GridWorld: Invalid floor %d for dungeon %s (has %d floors)" % [floor, dungeon_id, floor_data.size()])
		_build_default_grid()
		return
	var fd: Variant = floor_data[floor - 1]
	if not fd is Dictionary:
		DebugLog.data_issue(dungeon_id, "floor_data[%d]" % (floor - 1), "Dictionary", type_string(typeof(fd)))
		_build_default_grid()
		return
	var w: Variant = fd.get("width")
	var h: Variant = fd.get("height")
	if not w is int or not h is int:
		DebugLog.data_issue(dungeon_id, "floor_data[%d].width/height" % (floor - 1), "int", "width=%s, height=%s" % [w, h])
		_build_default_grid()
		return
	grid_width = w
	grid_height = h
	DebugLog.info("GridWorld: Loaded dungeon '%s' floor %d (%dx%d)" % [dungeon_id, floor, grid_width, grid_height])
	_generate_border_grid()
	_build_grid_mesh()
	_place_player_at_start()
	_update_camera()

func _build_default_grid() -> void:
	grid_width = 8
	grid_height = 8
	_generate_border_grid()
	_build_grid_mesh()
	_place_player_at_start()
	_update_camera()

func _generate_border_grid() -> void:
	grid_data.clear()
	for y in range(grid_height):
		var row: Array = []
		for x in range(grid_width):
			if x == 0 or x == grid_width - 1 or y == 0 or y == grid_height - 1:
				row.append(1)
			else:
				row.append(0)
		grid_data.append(row)

func _build_grid_mesh() -> void:
	for child in _dynamic_children:
		if is_instance_valid(child):
			child.queue_free()
	_dynamic_children.clear()
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
				_dynamic_children.append(wall)
			else:
				var floor_tile := floor_scene.instantiate()
				floor_tile.position = pos
				add_child(floor_tile)
				_dynamic_children.append(floor_tile)

func _place_player_at_start() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			if grid_data[y][x] == 0:
				player_grid_pos = Vector2i(x, y)
				return
	DebugLog.warn("GridWorld: No walkable tile found — player placed at (0,0) which may be a wall")
	player_grid_pos = Vector2i.ZERO

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

func _rotate_for_facing(dir: Vector2i) -> Vector2i:
	match player_facing:
		Facing.NORTH:
			return dir
		Facing.SOUTH:
			return Vector2i(-dir.x, -dir.y)
		Facing.EAST:
			return Vector2i(-dir.y, dir.x)
		Facing.WEST:
			return Vector2i(dir.y, -dir.x)
	return dir

func try_move(_actor_index: int, direction: Vector2i) -> bool:
	var target_dir := _rotate_for_facing(direction)
	var target_pos := player_grid_pos + target_dir
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
