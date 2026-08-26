extends Node

signal _turn_started(_turn_number: int)
signal _turn_ended(_turn_number: int)
signal party_changed()
signal inventory_changed()
signal game_event(text: String, color: Color)

enum GameState {
	MENU,
	EXPLORING,
	COMBAT,
	DIALOGUE,
	INVENTORY,
	PAUSED,
}

var current_state: GameState = GameState.MENU
var current_dungeon_id: String = ""
var current_floor: int = 1
var turn_count: int = 0

var party: Array[Dictionary] = []
var party_size: int:
	get:
		return party.size()

var inventory: Array[Dictionary] = []
var gold: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DataRegistry.all_data_loaded.is_connected(_on_data_ready):
		pass
	else:
		DataRegistry.all_data_loaded.connect(_on_data_ready)

func _on_data_ready() -> void:
	DebugLog.info("GameManager: Data ready, starting new game")
	start_new_game()

func start_new_game() -> void:
	_init_default_party()
	turn_count = 0
	current_dungeon_id = "dungeon_01"
	current_floor = 1
	current_state = GameState.EXPLORING
	DebugLog.info("GameManager: New game started — dungeon='%s' floor=%d party_size=%d" % [current_dungeon_id, current_floor, party.size()])
	party_changed.emit()

# --- Inventory ---

func add_item(item_id: String, qty: int = 1) -> void:
	if qty <= 0:
		DebugLog.warn("GameManager: add_item called with qty=%d for '%s'" % [qty, item_id])
		return
	if not DataRegistry.has_record(item_id):
		DebugLog.warn("GameManager: add_item — unknown item ID: '%s'" % item_id)
		return
	for entry in inventory:
		if entry["id"] == item_id:
			entry["quantity"] += qty
			DebugLog.info("GameManager: Added %dx '%s' (total: %d)" % [qty, item_id, entry["quantity"]])
			inventory_changed.emit()
			return
	inventory.append({ "id": item_id, "quantity": qty })
	DebugLog.info("GameManager: Added %dx '%s' (new stack)" % [qty, item_id])
	inventory_changed.emit()

func remove_item(item_id: String, qty: int = 1) -> bool:
	for i in range(inventory.size()):
		if inventory[i]["id"] == item_id:
			if inventory[i]["quantity"] < qty:
				DebugLog.warn("GameManager: remove_item — not enough '%s' (have %d, need %d)" % [item_id, inventory[i]["quantity"], qty])
				return false
			inventory[i]["quantity"] -= qty
			var remaining: int = inventory[i]["quantity"]
			if remaining <= 0:
				inventory.remove_at(i)
				DebugLog.info("GameManager: Removed all '%s'" % item_id)
			else:
				DebugLog.info("GameManager: Removed %dx '%s' (remaining: %d)" % [qty, item_id, remaining])
			inventory_changed.emit()
			return true
	DebugLog.warn("GameManager: remove_item — item '%s' not in inventory" % item_id)
	return false

func has_item(item_id: String) -> bool:
	for entry in inventory:
		if entry["id"] == item_id and entry["quantity"] > 0:
			return true
	return false

func get_item_quantity(item_id: String) -> int:
	for entry in inventory:
		if entry["id"] == item_id:
			return entry["quantity"]
	return 0

func get_inventory() -> Array[Dictionary]:
	return inventory

func equip_item(char_index: int, item_id: String) -> bool:
	if char_index < 0 or char_index >= party.size():
		DebugLog.warn("GameManager: equip_item — invalid character index %d" % char_index)
		return false
	var member: Dictionary = party[char_index]
	var item_record: Dictionary = DataRegistry.get_record(item_id)
	if item_record.is_empty():
		DebugLog.warn("GameManager: equip_item — unknown item '%s'" % item_id)
		return false
	var slot: String = item_record.get("slot", "")
	if slot.is_empty():
		DebugLog.warn("GameManager: equip_item — item '%s' has no slot" % item_id)
		return false
	var requirements: Dictionary = item_record.get("requirements", {})
	for stat in requirements:
		if member.get(stat, 0) < requirements[stat]:
			DebugLog.warn("GameManager: equip_item — %s lacks %s %d (has %d)" % [member["name"], stat, requirements[stat], member.get(stat, 0)])
			return false
	var equipment: Dictionary = member["equipment"]
	var old_item_id: String = equipment.get(slot, "")
	equipment[slot] = item_id
	if old_item_id != "":
		add_item(old_item_id, 1)
		DebugLog.info("GameManager: %s unequipped '%s'" % [member["name"], old_item_id])
	if has_item(item_id):
		remove_item(item_id, 1)
	DebugLog.info("GameManager: %s equipped '%s' to %s" % [member["name"], item_id, slot])
	party_changed.emit()
	inventory_changed.emit()
	return true

func unequip_item(char_index: int, slot: String) -> bool:
	if char_index < 0 or char_index >= party.size():
		DebugLog.warn("GameManager: unequip_item — invalid character index %d" % char_index)
		return false
	var member: Dictionary = party[char_index]
	var equipment: Dictionary = member["equipment"]
	var item_id: String = equipment.get(slot, "")
	if item_id.is_empty():
		DebugLog.warn("GameManager: unequip_item — %s has nothing in %s" % [member["name"], slot])
		return false
	add_item(item_id, 1)
	equipment[slot] = ""
	DebugLog.info("GameManager: %s unequipped '%s' from %s" % [member["name"], item_id, slot])
	party_changed.emit()
	inventory_changed.emit()
	return true

func _init_default_party() -> void:
	party = []
	var default_characters: Array[Dictionary] = [
		{
			"id": "warrior_01",
			"name": "Roland",
			"class_id": "warrior",
			"level": 1,
			"xp": 0,
			"xp_to_next": 100,
			"equipment": {
				"main_hand": "sword_iron",
				"off_hand": "shield_wood",
				"head": "",
				"body": "armor_leather",
				"legs": "",
				"accessory": "",
			},
			"spells": [],
			"skills": ["power_strike"],
		},
		{
			"id": "mage_01",
			"name": "Elara",
			"class_id": "mage",
			"level": 1,
			"xp": 0,
			"xp_to_next": 100,
			"equipment": {
				"main_hand": "staff_wood",
				"off_hand": "",
				"head": "",
				"body": "robe_cloth",
				"legs": "",
				"accessory": "",
			},
			"spells": ["fireball", "heal"],
			"skills": [],
		},
		{
			"id": "cleric_01",
			"name": "Aldric",
			"class_id": "cleric",
			"level": 1,
			"xp": 0,
			"xp_to_next": 100,
			"equipment": {
				"main_hand": "mace_iron",
				"off_hand": "shield_wood",
				"head": "",
				"body": "armor_chain",
				"legs": "",
				"accessory": "",
			},
			"spells": ["heal", "smite"],
			"skills": [],
		},
		{
			"id": "thief_01",
			"name": "Shade",
			"class_id": "thief",
			"level": 1,
			"xp": 0,
			"xp_to_next": 100,
			"equipment": {
				"main_hand": "dagger_steel",
				"off_hand": "",
				"head": "",
				"body": "armor_leather",
				"legs": "",
				"accessory": "",
			},
			"spells": [],
			"skills": ["backstab", "pick_lock"],
		},
	]
	for char in default_characters:
		var class_record: Dictionary = DataRegistry.get_record(char["class_id"])
		if class_record.is_empty():
			DebugLog.warn("GameManager: Class record not found: %s — skipping %s" % [char["class_id"], char["name"]])
			continue
		var base_stats: Dictionary = class_record.get("base_stats", {})
		if base_stats.is_empty():
			DebugLog.warn("GameManager: Class '%s' has no base_stats — skipping %s" % [char["class_id"], char["name"]])
			continue
		var stat_keys := ["hp", "mp", "strength", "defense", "vitality", "energy", "agility", "luck"]
		for key in stat_keys:
			if not base_stats.has(key):
				DebugLog.data_issue(char["class_id"], "base_stats.%s" % key, "int", "missing — defaulting to 1")
				base_stats[key] = 1
		char["hp"] = int(base_stats["hp"])
		char["max_hp"] = int(base_stats["hp"])
		char["mp"] = int(base_stats["mp"])
		char["max_mp"] = int(base_stats["mp"])
		char["strength"] = int(base_stats["strength"])
		char["defense"] = int(base_stats["defense"])
		char["vitality"] = int(base_stats["vitality"])
		char["energy"] = int(base_stats["energy"])
		char["agility"] = int(base_stats["agility"])
		char["luck"] = int(base_stats["luck"])
		party.append(char)
		DebugLog.info("GameManager: Initialized %s (HP:%d MP:%d STR:%d DEF:%d)" % [char["name"], char["hp"], char["mp"], char["strength"], char["defense"]])

func get_party_member(index: int) -> Dictionary:
	if index >= 0 and index < party.size():
		return party[index]
	return {}

func heal_party_member(index: int, amount: int) -> void:
	if index < 0 or index >= party.size():
		return
	var member: Dictionary = party[index]
	member["hp"] = mini(member["hp"] + amount, member["max_hp"])
	party_changed.emit()

func damage_party_member(index: int, amount: int) -> void:
	if index < 0 or index >= party.size():
		return
	var member: Dictionary = party[index]
	member["hp"] = maxi(member["hp"] - amount, 0)
	party_changed.emit()

func is_party_alive() -> bool:
	for member in party:
		if member["hp"] > 0:
			return true
	return false

func get_version() -> String:
	var version_file := FileAccess.open("res://VERSION", FileAccess.READ)
	if version_file:
		return version_file.get_as_text().strip_edges()
	return "unknown"
