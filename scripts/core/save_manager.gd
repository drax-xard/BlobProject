extends Node

const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 5

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

# --- Public API ---

func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		DebugLog.warn("SaveManager: Invalid slot %d" % slot)
		return false
	var data := _build_save_data()
	data["slot"] = slot
	data["timestamp"] = Time.get_datetime_string_from_system()
	data["version"] = GameManager.get_version()
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		DebugLog.error("SaveManager: Could not write to %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	DebugLog.info("SaveManager: Game saved to slot %d" % slot)
	return true

func load_game(slot: int) -> bool:
	if not has_save(slot):
		DebugLog.warn("SaveManager: No save in slot %d" % slot)
		return false
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		DebugLog.error("SaveManager: Could not read %s" % path)
		return false
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		DebugLog.error("SaveManager: Parse error in %s: %s" % [path, json.get_error_message()])
		return false
	var data: Dictionary = json.data
	_apply_save_data(data)
	DebugLog.info("SaveManager: Game loaded from slot %d" % slot)
	return true

func delete_save(slot: int) -> bool:
	if not has_save(slot):
		return false
	var path := _slot_path(slot)
	DirAccess.remove_absolute(path)
	DebugLog.info("SaveManager: Deleted save slot %d" % slot)
	return true

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func get_save_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"slot": slot,
		"version": data.get("version", "unknown"),
		"timestamp": data.get("timestamp", "unknown"),
		"dungeon_id": data.get("dungeon_id", ""),
		"floor": data.get("floor", 1),
		"turn_count": data.get("turn_count", 0),
		"gold": data.get("gold", 0),
		"party_size": data.get("party", []).size(),
		"party_names": _extract_party_names(data.get("party", [])),
	}

func get_all_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		slots.append(get_save_info(i))
	return slots

# --- Build / Apply ---

func _build_save_data() -> Dictionary:
	var data: Dictionary = {}
	data["party"] = GameManager.party.duplicate(true)
	data["inventory"] = GameManager.inventory.duplicate(true)
	data["gold"] = GameManager.gold
	data["dungeon_id"] = GameManager.current_dungeon_id
	data["floor"] = GameManager.current_floor
	data["turn_count"] = GameManager.turn_count
	var grid_world := _get_grid_world()
	if grid_world:
		data["player_grid_pos"] = {"x": grid_world.player_grid_pos.x, "y": grid_world.player_grid_pos.y}
		data["player_facing"] = grid_world.player_facing
	return data

func _apply_save_data(data: Dictionary) -> void:
	GameManager.party = data.get("party", [])
	GameManager.inventory = data.get("inventory", [])
	GameManager.gold = data.get("gold", 0)
	GameManager.current_dungeon_id = data.get("dungeon_id", "")
	GameManager.current_floor = data.get("floor", 1)
	GameManager.turn_count = data.get("turn_count", 0)
	GameManager.current_state = GameManager.GameState.EXPLORING
	var grid_world := _get_grid_world()
	if grid_world:
		var pos_data: Dictionary = data.get("player_grid_pos", {"x": 0, "y": 0})
		grid_world.player_grid_pos = Vector2i(pos_data.get("x", 0), pos_data.get("y", 0))
		grid_world.player_facing = data.get("player_facing", 0)
		grid_world.load_dungeon(GameManager.current_dungeon_id, GameManager.current_floor)
	GameManager.party_changed.emit()
	GameManager.inventory_changed.emit()
	GameManager.game_loaded.emit()

# --- Helpers ---

func _get_grid_world() -> Node:
	var scene: Node = get_tree().current_scene
	if not scene:
		return null
	var viewport: SubViewportContainer = scene.find_child("ViewportFrame", true, false)
	if not viewport:
		return null
	var sub_viewport: SubViewport = viewport.get_node_or_null("SubViewport")
	if not sub_viewport:
		return null
	return sub_viewport.get_node_or_null("World")

func _slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("save_%d.json" % slot)

func _extract_party_names(party: Array) -> Array[String]:
	var names: Array[String] = []
	for member in party:
		if member is Dictionary:
			names.append(member.get("name", "?"))
	return names
