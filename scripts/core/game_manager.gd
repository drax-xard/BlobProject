extends Node

signal _turn_started(_turn_number: int)
signal _turn_ended(_turn_number: int)
signal party_changed()

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_new_game()

func start_new_game() -> void:
	_init_default_party()
	turn_count = 0
	current_state = GameState.EXPLORING
	party_changed.emit()

func _init_default_party() -> void:
	party = []
	var default_characters := [
		{
			"id": "warrior_01",
			"name": "Roland",
			"class_id": "warrior",
			"level": 1,
			"hp": 45,
			"max_hp": 45,
			"mp": 10,
			"max_mp": 10,
			"strength": 12,
			"defense": 10,
			"vitality": 10,
			"energy": 6,
			"agility": 8,
			"luck": 6,
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
			"hp": 25,
			"max_hp": 25,
			"mp": 40,
			"max_mp": 40,
			"strength": 4,
			"defense": 4,
			"vitality": 6,
			"energy": 14,
			"agility": 8,
			"luck": 8,
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
			"hp": 35,
			"max_hp": 35,
			"mp": 30,
			"max_mp": 30,
			"strength": 8,
			"defense": 8,
			"vitality": 12,
			"energy": 10,
			"agility": 6,
			"luck": 8,
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
			"hp": 30,
			"max_hp": 30,
			"mp": 15,
			"max_mp": 15,
			"strength": 8,
			"defense": 6,
			"vitality": 8,
			"energy": 6,
			"agility": 14,
			"luck": 12,
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
	party = default_characters

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
