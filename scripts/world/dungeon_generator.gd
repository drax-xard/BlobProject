class_name DungeonGenerator

const CELL_FLOOR: int = 0
const CELL_WALL: int = 1
const CELL_DOOR: int = 2
const CELL_STAIRS_UP: int = 3
const CELL_STAIRS_DOWN: int = 4
const CELL_CHEST: int = 7
const CELL_NPC: int = 8

var _rng: RandomNumberGenerator
var _grid: Array[Array] = []
var _rooms: Array[Dictionary] = []
var _grid_width: int = 0
var _grid_height: int = 0

func generate(width: int, height: int, dungeon_seed: int) -> Dictionary:
	_grid_width = width
	_grid_height = height
	_rng = RandomNumberGenerator.new()
	_rng.seed = dungeon_seed
	_grid = []
	_rooms = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(CELL_WALL)
		_grid.append(row)
	var root: Dictionary = { "x": 0, "y": 0, "w": width, "h": height }
	var leaves: Array[Dictionary] = []
	_bsp_split(root, leaves, 0)
	_place_rooms(leaves)
	_connect_rooms()
	_place_specials()
	return {
		"grid": _grid,
		"rooms": _rooms,
		"stairs_up_pos": _get_stairs_up_pos(),
		"stairs_down_pos": _get_stairs_down_pos(),
	}

func _bsp_split(node: Dictionary, leaves: Array[Dictionary], depth: int) -> void:
	var min_size: int = 4
	if depth >= 5 or (node["w"] <= min_size * 2 and node["h"] <= min_size * 2):
		leaves.append(node)
		return
	var split_horizontal: bool
	if node["w"] > node["h"] * 1.25:
		split_horizontal = false
	elif node["h"] > node["w"] * 1.25:
		split_horizontal = true
	else:
		split_horizontal = _rng.randi() % 2 == 0
	if split_horizontal:
		if node["h"] < min_size * 2:
			leaves.append(node)
			return
		var split_pos: int = _rng.randi_range(min_size, node["h"] - min_size)
		var child_a: Dictionary = { "x": node["x"], "y": node["y"], "w": node["w"], "h": split_pos }
		var child_b: Dictionary = { "x": node["x"], "y": node["y"] + split_pos, "w": node["w"], "h": node["h"] - split_pos }
		_bsp_split(child_a, leaves, depth + 1)
		_bsp_split(child_b, leaves, depth + 1)
	else:
		if node["w"] < min_size * 2:
			leaves.append(node)
			return
		var split_pos: int = _rng.randi_range(min_size, node["w"] - min_size)
		var child_a: Dictionary = { "x": node["x"], "y": node["y"], "w": split_pos, "h": node["h"] }
		var child_b: Dictionary = { "x": node["x"] + split_pos, "y": node["y"], "w": node["w"] - split_pos, "h": node["h"] }
		_bsp_split(child_a, leaves, depth + 1)
		_bsp_split(child_b, leaves, depth + 1)

func _place_rooms(leaves: Array[Dictionary]) -> void:
	for leaf in leaves:
		var padding: int = 1
		var max_w: int = leaf["w"] - padding * 2
		var max_h: int = leaf["h"] - padding * 2
		if max_w < 2 or max_h < 2:
			continue
		var room_w: int = _rng.randi_range(2, max_w)
		var room_h: int = _rng.randi_range(2, max_h)
		var room_x: int = _rng.randi_range(leaf["x"] + padding, leaf["x"] + leaf["w"] - room_w - padding)
		var room_y: int = _rng.randi_range(leaf["y"] + padding, leaf["y"] + leaf["h"] - room_h - padding)
		var room: Dictionary = {
			"x": room_x, "y": room_y,
			"w": room_w, "h": room_h,
			"cx": room_x + room_w / 2,
			"cy": room_y + room_h / 2,
		}
		_carve_room(room)
		_rooms.append(room)

func _carve_room(room: Dictionary) -> void:
	for y in range(room["y"], room["y"] + room["h"]):
		for x in range(room["x"], room["x"] + room["w"]):
			if y >= 0 and y < _grid_height and x >= 0 and x < _grid_width:
				_grid[y][x] = CELL_FLOOR

func _connect_rooms() -> void:
	if _rooms.size() < 2:
		return
	var connected: Array[Dictionary] = [_rooms[0]]
	var remaining: Array[Dictionary] = []
	for i in range(1, _rooms.size()):
		remaining.append(_rooms[i])
	while remaining.size() > 0:
		var best_dist: float = INF
		var best_conn: int = -1
		var best_rem: int = -1
		for ci in range(connected.size()):
			for ri in range(remaining.size()):
				var dx: float = connected[ci]["cx"] - remaining[ri]["cx"]
				var dy: float = connected[ci]["cy"] - remaining[ri]["cy"]
				var dist: float = dx * dx + dy * dy
				if dist < best_dist:
					best_dist = dist
					best_conn = ci
					best_rem = ri
		if best_conn >= 0 and best_rem >= 0:
			_carve_corridor(connected[best_conn], remaining[best_rem])
			connected.append(remaining[best_rem])
			remaining.remove_at(best_rem)

func _carve_corridor(room_a: Dictionary, room_b: Dictionary) -> void:
	var ax: int = room_a["cx"]
	var ay: int = room_a["cy"]
	var bx: int = room_b["cx"]
	var by: int = room_b["cy"]
	if _rng.randi() % 2 == 0:
		_carve_h_corridor(ax, bx, ay)
		_carve_v_corridor(ay, by, bx)
	else:
		_carve_v_corridor(ay, by, ax)
		_carve_h_corridor(ax, bx, by)

func _carve_h_corridor(x1: int, x2: int, y: int) -> void:
	var start_x: int = mini(x1, x2)
	var end_x: int = maxi(x1, x2)
	for x in range(start_x, end_x + 1):
		if y >= 0 and y < _grid_height and x >= 0 and x < _grid_width:
			_grid[y][x] = CELL_FLOOR

func _carve_v_corridor(y1: int, y2: int, x: int) -> void:
	var start_y: int = mini(y1, y2)
	var end_y: int = maxi(y1, y2)
	for y in range(start_y, end_y + 1):
		if y >= 0 and y < _grid_height and x >= 0 and x < _grid_width:
			_grid[y][x] = CELL_FLOOR

func _place_specials() -> void:
	if _rooms.is_empty():
		return
	_rooms[0]["type"] = "start"
	_grid[_rooms[0]["cy"]][_rooms[0]["cx"]] = CELL_STAIRS_UP
	if _rooms.size() > 1:
		var last: Dictionary = _rooms[_rooms.size() - 1]
		last["type"] = "exit"
		_grid[last["cy"]][last["cx"]] = CELL_STAIRS_DOWN
	var chest_candidates: Array[Dictionary] = []
	for i in range(1, _rooms.size() - 1):
		chest_candidates.append(_rooms[i])
	chest_candidates.shuffle()
	var chest_count: int = mini(2, chest_candidates.size())
	for i in range(chest_count):
		var room: Dictionary = chest_candidates[i]
		_grid[room["cy"]][room["cx"]] = CELL_CHEST

func _get_stairs_up_pos() -> Vector2i:
	if _rooms.is_empty():
		return Vector2i(_grid_width / 2, _grid_height / 2)
	return Vector2i(_rooms[0]["cx"], _rooms[0]["cy"])

func _get_stairs_down_pos() -> Vector2i:
	if _rooms.size() < 2:
		if _rooms.is_empty():
			return Vector2i(_grid_width / 2, _grid_height / 2)
		return Vector2i(_rooms[0]["cx"], _rooms[0]["cy"])
	var last: Dictionary = _rooms[_rooms.size() - 1]
	return Vector2i(last["cx"], last["cy"])
