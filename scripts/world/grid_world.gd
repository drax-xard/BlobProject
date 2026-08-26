extends Node3D

signal player_moved(new_position: Vector2i)
signal player_turned(new_facing: int)
signal player_stair_state(is_on_stairs: bool, stair_type: String)

const CELL_SIZE: float = 2.0

enum Facing { NORTH, EAST, SOUTH, WEST }

var grid_data: Array[Array] = []
var grid_width: int = 0
var grid_height: int = 0
var player_grid_pos: Vector2i = Vector2i.ZERO
var player_facing: int = Facing.NORTH

var _encounter_rate: float = 0.0
var _encounter_tables: Dictionary = {}
var _combat_manager: Node = null
var _stairs_up_pos: Vector2i = Vector2i.ZERO
var _stairs_down_pos: Vector2i = Vector2i.ZERO
var _current_dungeon_id: String = ""
var _current_floor: int = 1
var _npc_positions: Dictionary = {}
var _last_interacted_cell: Vector2i = Vector2i(-1, -1)

@onready var camera: Camera3D = $Camera3D

var _dynamic_children: Array[Node] = []

func _ready() -> void:
	if GameManager.party.size() > 0:
		_load_dungeon_for_game()
	else:
		GameManager.party_changed.connect(_load_dungeon_for_game, CONNECT_ONE_SHOT)
	GameManager.game_loaded.connect(_on_game_loaded)

func _on_game_loaded() -> void:
	load_dungeon(GameManager.current_dungeon_id, GameManager.current_floor)
	player_grid_pos = GameManager.saved_player_pos
	player_facing = GameManager.saved_player_facing
	_update_camera()
	_notify_stair_state()

func _load_dungeon_for_game() -> void:
	if GameManager.current_dungeon_id.is_empty():
		DebugLog.warn("GridWorld: No dungeon ID set, using default grid")
		_build_default_grid()
		return
	load_dungeon(GameManager.current_dungeon_id, GameManager.current_floor)

func load_dungeon(dungeon_id: String, floor: int) -> void:
	_current_dungeon_id = dungeon_id
	_current_floor = floor
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
	if not (w is int or w is float) or not (h is int or h is float):
		DebugLog.data_issue(dungeon_id, "floor_data[%d].width/height" % (floor - 1), "int or float", "width=%s, height=%s" % [w, h])
		_build_default_grid()
		return
	grid_width = int(w)
	grid_height = int(h)
	_encounter_rate = float(fd.get("encounter_rate", 0.0))
	_encounter_tables = dungeon_record.get("encounter_tables", {})
	_combat_manager = get_tree().current_scene.get_node_or_null("CombatManager")
	DebugLog.info("GridWorld: Loaded dungeon '%s' floor %d (%dx%d, encounter_rate=%.2f)" % [dungeon_id, floor, grid_width, grid_height, _encounter_rate])
	GameManager.game_event.emit("Entered %s, floor %d" % [dungeon_record.get("name", dungeon_id), floor], Color(0.7, 0.85, 1.0))
	_generate_dungeon(dungeon_id, floor)
	_build_grid_mesh()
	_place_player_at_stairs_up()
	_update_camera()
	_notify_stair_state()

func _build_default_grid() -> void:
	grid_width = 8
	grid_height = 8
	_current_dungeon_id = ""
	_current_floor = 1
	_generate_border_grid()
	_build_grid_mesh()
	_place_player_at_start()
	_update_camera()

func _generate_dungeon(dungeon_id: String, floor: int) -> void:
	var dungeon_record: Dictionary = DataRegistry.get_record(dungeon_id)
	var floor_data_arr: Variant = dungeon_record.get("floor_data", [])
	var current_fd: Dictionary = {}
	if floor_data_arr is Array and floor - 1 < floor_data_arr.size():
		current_fd = floor_data_arr[floor - 1]
	var layout: Variant = current_fd.get("layout")
	if layout is Array and layout.size() > 0:
		var npcs: Array = current_fd.get("npcs", [])
		_load_layout(layout, npcs)
		return
	var gen := DungeonGenerator.new()
	var seed_value: int = hash(dungeon_id) + floor * 1000
	var result: Dictionary = gen.generate(grid_width, grid_height, seed_value)
	grid_data = result["grid"]
	_stairs_up_pos = result["stairs_up_pos"]
	_stairs_down_pos = result["stairs_down_pos"]
	DebugLog.info("GridWorld: Generated dungeon with %d rooms, stairs_up=%s, stairs_down=%s" % [
		result["rooms"].size(), _stairs_up_pos, _stairs_down_pos
	])

func _load_layout(layout: Array, npcs: Array = []) -> void:
	grid_data.clear()
	_npc_positions.clear()
	for y in range(layout.size()):
		var row: Array = layout[y]
		var grid_row: Array = []
		for x in range(row.size()):
			var cell: int = int(row[x])
			grid_row.append(cell)
			if cell == DungeonGenerator.CELL_STAIRS_UP:
				_stairs_up_pos = Vector2i(x, y)
			elif cell == DungeonGenerator.CELL_STAIRS_DOWN:
				_stairs_down_pos = Vector2i(x, y)
		grid_data.append(grid_row)
	for npc_data in npcs:
		if npc_data is Dictionary:
			var pos: Dictionary = npc_data.get("pos", {})
			var key := Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))
			_npc_positions[key] = npc_data.get("id", "")
	DebugLog.info("GridWorld: Loaded hand-crafted layout (%dx%d, %d NPCs)" % [grid_width, grid_height, _npc_positions.size()])

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
			if cell == DungeonGenerator.CELL_WALL:
				var wall := wall_scene.instantiate()
				wall.position = pos + Vector3(0.0, CELL_SIZE * 0.5, 0.0)
				add_child(wall)
				_dynamic_children.append(wall)
			else:
				var floor_tile := floor_scene.instantiate()
				floor_tile.position = pos
				add_child(floor_tile)
				_dynamic_children.append(floor_tile)
				if cell == DungeonGenerator.CELL_STAIRS_DOWN or cell == DungeonGenerator.CELL_STAIRS_UP:
					var tex_path := "stairs_down.png" if cell == DungeonGenerator.CELL_STAIRS_DOWN else "stairs_up.png"
					var marker := _create_tile_marker(pos, Color(0.2, 0.8, 0.2), tex_path)
					add_child(marker)
					_dynamic_children.append(marker)
				elif cell == DungeonGenerator.CELL_CHEST:
					var marker := _create_tile_marker(pos, Color(0.9, 0.7, 0.1), "chest_closed.png")
					add_child(marker)
					_dynamic_children.append(marker)
				elif cell == DungeonGenerator.CELL_NPC:
					var npc_key := Vector2i(x, y)
					if _npc_positions.has(npc_key):
						var npc_id: String = _npc_positions[npc_key]
						var banner := _create_npc_banner(npc_id)
						if banner:
							banner.position = pos + Vector3(0.0, 1.0, 0.0)
							add_child(banner)
							_dynamic_children.append(banner)

func _place_player_at_start() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			if grid_data[y][x] != DungeonGenerator.CELL_WALL:
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
	var cell: int = grid_data[grid_pos.y][grid_pos.x]
	return cell != DungeonGenerator.CELL_WALL

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
	if player_grid_pos != _last_interacted_cell:
		_last_interacted_cell = Vector2i(-1, -1)
	_sync_position_to_game_manager()
	_update_camera()
	player_moved.emit(player_grid_pos)
	_check_random_encounter()
	if GameManager.current_state == GameManager.GameState.EXPLORING:
		check_tile_interaction()
	return true

func try_turn(_actor_index: int, turn_dir: int) -> bool:
	player_facing = posmod(player_facing + turn_dir, 4)
	_sync_position_to_game_manager()
	_update_camera()
	player_turned.emit(player_facing)
	return true

func _sync_position_to_game_manager() -> void:
	GameManager.saved_player_pos = player_grid_pos
	GameManager.saved_player_facing = player_facing

func get_cell(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= grid_width:
		return 1
	if grid_pos.y < 0 or grid_pos.y >= grid_height:
		return 1
	return grid_data[grid_pos.y][grid_pos.x]

func _check_random_encounter() -> void:
	if _encounter_rate <= 0.0:
		return
	if not _combat_manager:
		_combat_manager = get_tree().current_scene.get_node_or_null("CombatManager")
	if not _combat_manager:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORING:
		return
	if randf() >= _encounter_rate:
		return
	var enemy_ids: Array[String] = _pick_encounter()
	if enemy_ids.is_empty():
		return
	_combat_manager.start_encounter(enemy_ids)

func _pick_encounter() -> Array[String]:
	var result: Array[String] = []
	var tier: String = _get_encounter_tier()
	var table: Variant = _encounter_tables.get(tier, [])
	if not table is Array or table.is_empty():
		table = _encounter_tables.get("easy", [])
	if not table is Array or table.is_empty():
		return result
	var total_weight: int = 0
	for entry in table:
		if entry is Dictionary:
			total_weight += int(entry.get("weight", 1))
	if total_weight <= 0:
		return result
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for entry in table:
		if not entry is Dictionary:
			continue
		cumulative += int(entry.get("weight", 1))
		if roll < cumulative:
			var enemies: Variant = entry.get("enemies", [])
			if enemies is Array:
				for eid in enemies:
					if eid is String:
						result.append(eid)
			break
	return result

func _get_encounter_tier() -> String:
	match GameManager.current_floor:
		1:
			return "easy"
		2:
			return "medium"
		_:
			return "hard"

func _place_player_at_stairs_up() -> void:
	if _stairs_up_pos != Vector2i.ZERO and is_walkable(_stairs_up_pos):
		player_grid_pos = _stairs_up_pos
		return
	_place_player_at_start()

func _player_on_stairs(stair_type: String, pos: Vector2i) -> void:
	player_stair_state.emit(not stair_type.is_empty(), stair_type)

func _notify_stair_state() -> void:
	if grid_data.size() == 0:
		return
	if player_grid_pos.x < 0 or player_grid_pos.x >= grid_width:
		return
	if player_grid_pos.y < 0 or player_grid_pos.y >= grid_height:
		return
	var cell: int = grid_data[player_grid_pos.y][player_grid_pos.x]
	match cell:
		DungeonGenerator.CELL_STAIRS_DOWN:
			_player_on_stairs("stairs_down", player_grid_pos)
		DungeonGenerator.CELL_STAIRS_UP:
			_player_on_stairs("stairs_up", player_grid_pos)
		_:
			_player_on_stairs("", player_grid_pos)

func use_stair() -> void:
	if grid_data.size() == 0:
		return
	if player_grid_pos.x < 0 or player_grid_pos.x >= grid_width:
		return
	if player_grid_pos.y < 0 or player_grid_pos.y >= grid_height:
		return
	var cell: int = grid_data[player_grid_pos.y][player_grid_pos.x]
	match cell:
		DungeonGenerator.CELL_STAIRS_DOWN:
			_transition_to_next_floor()
		DungeonGenerator.CELL_STAIRS_UP:
			_transition_to_previous_floor()

func _create_tile_marker(world_pos: Vector3, color: Color, texture_path: String = "") -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE * 0.6, 0.2, CELL_SIZE * 0.6)
	marker.mesh = box
	marker.position = world_pos + Vector3(0.0, 0.05, 0.0)
	var mat := StandardMaterial3D.new()
	if not texture_path.is_empty():
		var tex := ResLoader.load_texture("base", texture_path)
		if tex:
			mat.albedo_texture = tex
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		else:
			mat.albedo_color = color
	else:
		mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	marker.material_override = mat
	return marker

func _create_npc_banner(npc_id: String) -> Sprite3D:
	var record: Dictionary = DataRegistry.get_record(npc_id)
	var portrait_path: String = record.get("portrait", "")
	if portrait_path.is_empty():
		return null
	var tex := ResLoader.load_texture("base", portrait_path)
	if not tex:
		return null
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = 0.01
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.9)
	return sprite

func check_tile_interaction() -> void:
	if grid_data.size() == 0:
		_player_on_stairs("", Vector2i.ZERO)
		return
	if player_grid_pos.x < 0 or player_grid_pos.x >= grid_width:
		_player_on_stairs("", Vector2i.ZERO)
		return
	if player_grid_pos.y < 0 or player_grid_pos.y >= grid_height:
		_player_on_stairs("", Vector2i.ZERO)
		return
	if player_grid_pos == _last_interacted_cell:
		_last_interacted_cell = Vector2i(-1, -1)
		_player_on_stairs("", player_grid_pos)
		return
	var cell: int = grid_data[player_grid_pos.y][player_grid_pos.x]
	match cell:
		DungeonGenerator.CELL_STAIRS_DOWN:
			_player_on_stairs("stairs_down", player_grid_pos)
		DungeonGenerator.CELL_STAIRS_UP:
			_player_on_stairs("stairs_up", player_grid_pos)
		DungeonGenerator.CELL_CHEST:
			_open_chest()
			_player_on_stairs("", player_grid_pos)
		DungeonGenerator.CELL_NPC:
			_interact_with_npc()
			_player_on_stairs("", player_grid_pos)
		_:
			_player_on_stairs("", player_grid_pos)

func _transition_to_next_floor() -> void:
	if _current_dungeon_id.is_empty():
		return
	var dungeon_record: Dictionary = DataRegistry.get_record(_current_dungeon_id)
	var floor_data: Variant = dungeon_record.get("floor_data", [])
	if _current_floor >= floor_data.size():
		GameManager.game_event.emit("Reached the end of the dungeon!", Color(1.0, 0.9, 0.3))
		DebugLog.info("GridWorld: Reached the end of the dungeon!")
		return
	GameManager.game_event.emit("Descending to floor %d..." % (_current_floor + 1), Color(0.7, 0.7, 1.0))
	GameManager.current_floor = _current_floor + 1
	load_dungeon(_current_dungeon_id, GameManager.current_floor)

func _transition_to_previous_floor() -> void:
	if _current_floor <= 1:
		return
	if _current_dungeon_id.is_empty():
		return
	GameManager.current_floor = _current_floor - 1
	load_dungeon(_current_dungeon_id, GameManager.current_floor)

func _open_chest() -> void:
	if player_grid_pos.x < 0 or player_grid_pos.x >= grid_width:
		return
	if player_grid_pos.y < 0 or player_grid_pos.y >= grid_height:
		return
	grid_data[player_grid_pos.y][player_grid_pos.x] = DungeonGenerator.CELL_FLOOR
	_build_grid_mesh()
	var gold_found: int = randi_range(5, 20)
	GameManager.add_item("potion_health", 1)
	GameManager.gold += gold_found
	GameManager.inventory_changed.emit()
	GameManager.game_event.emit("Found a Health Potion and %d gold!" % gold_found, Color(1.0, 0.85, 0.2))
	DebugLog.info("GridWorld: Opened chest! Found health potion and %d gold." % gold_found)

func _interact_with_npc() -> void:
	if _npc_positions.has(player_grid_pos):
		var npc_id: String = _npc_positions[player_grid_pos]
		if not npc_id.is_empty():
			_last_interacted_cell = player_grid_pos
			DialogueManager.start_dialogue(npc_id)
