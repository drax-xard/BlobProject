extends Node

signal dialogue_started(npc_id: String, npc_name: String)
signal dialogue_ended()
signal dialogue_node_changed(node_id: String, text: String, choices: Array)
signal dialogue_effect(effect: Dictionary)

var _active: bool = false
var _npc_id: String = ""
var _npc_record: Dictionary = {}
var _tree: Dictionary = {}
var _current_node_id: String = ""
var _current_node: Dictionary = {}

# --- Public API ---

func start_dialogue(npc_id: String) -> void:
	var record: Dictionary = DataRegistry.get_record(npc_id)
	if record.is_empty():
		DebugLog.warn("DialogueManager: NPC record '%s' not found" % npc_id)
		return
	if _active:
		DebugLog.warn("DialogueManager: Dialogue already active with '%s'" % _npc_id)
		return
	_npc_id = npc_id
	_npc_record = record
	_tree = record.get("dialogue_tree", {})
	if _tree.is_empty():
		DebugLog.warn("DialogueManager: NPC '%s' has no dialogue_tree" % npc_id)
		return
	_active = true
	_current_node_id = "start"
	_enter_node("start")
	var npc_name: String = record.get("name", npc_id)
	dialogue_started.emit(npc_id, npc_name)
	GameManager.current_state = GameManager.GameState.DIALOGUE
	DebugLog.info("DialogueManager: Started dialogue with '%s'" % npc_name)

func select_choice(choice_index: int) -> void:
	if not _active:
		return
	var choices: Array = _current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		DebugLog.warn("DialogueManager: Invalid choice index %d" % choice_index)
		return
	var choice: Dictionary = choices[choice_index]
	var effects: Array = choice.get("effects", [])
	for effect in effects:
		_apply_effect(effect)
		dialogue_effect.emit(effect)
	var next: Variant = choice.get("next")
	if next == null or (next is String and next.is_empty()):
		end_dialogue()
	elif next is String:
		_enter_node(next)

func end_dialogue() -> void:
	if not _active:
		return
	var npc_name: String = _npc_record.get("name", _npc_id)
	_active = false
	_npc_id = ""
	_npc_record = {}
	_tree = {}
	_current_node_id = ""
	_current_node = {}
	dialogue_ended.emit()
	if GameManager.current_state == GameManager.GameState.DIALOGUE:
		GameManager.current_state = GameManager.GameState.EXPLORING
	DebugLog.info("DialogueManager: Ended dialogue with '%s'" % npc_name)

func is_active() -> bool:
	return _active

func get_npc_name() -> String:
	return _npc_record.get("name", _npc_id)

func get_npc_id() -> String:
	return _npc_id

func get_current_text() -> String:
	return _current_node.get("text", "")

func get_current_choices() -> Array:
	return _current_node.get("choices", [])

func get_shop_inventory() -> Array:
	return _npc_record.get("shop_inventory", [])

# --- Internal ---

func _enter_node(node_id: String) -> void:
	if not _tree.has(node_id):
		DebugLog.warn("DialogueManager: Node '%s' not found in dialogue tree" % node_id)
		end_dialogue()
		return
	_current_node_id = node_id
	_current_node = _tree[node_id]
	var node_effects: Array = _current_node.get("effects", [])
	for effect in node_effects:
		_apply_effect(effect)
		dialogue_effect.emit(effect)
	var available_choices := _filter_choices(_current_node.get("choices", []))
	_current_node["choices"] = available_choices
	dialogue_node_changed.emit(node_id, _current_node.get("text", ""), available_choices)

func _filter_choices(choices: Array) -> Array:
	var filtered: Array = []
	for choice in choices:
		if not choice is Dictionary:
			continue
		var condition: Variant = choice.get("condition")
		if condition == null or _evaluate_condition(condition):
			filtered.append(choice)
	return filtered

func _evaluate_condition(condition: Dictionary) -> bool:
	if condition.has("has_item"):
		return GameManager.has_item(condition["has_item"])
	if condition.has("flag"):
		return GameManager.has_flag(condition["flag"])
	if condition.has("gold_min"):
		return GameManager.gold >= int(condition["gold_min"])
	if condition.has("quest_complete"):
		return GameManager.is_quest_complete(condition["quest_complete"])
	if condition.has("quest_started"):
		return GameManager.is_quest_started(condition["quest_started"])
	if condition.has("stat_check"):
		var stat: String = condition["stat_check"].get("stat", "")
		var min_val: int = int(condition["stat_check"].get("min", 0))
		for member in GameManager.party:
			if member is Dictionary and int(member.get(stat, 0)) >= min_val:
				return true
		return false
	return true

func _apply_effect(effect: Dictionary) -> void:
	if effect.has("give_item"):
		var qty: int = int(effect.get("qty", 1))
		GameManager.add_item(effect["give_item"], qty)
		DebugLog.info("DialogueManager: give_item %s x%d" % [effect["give_item"], qty])
	if effect.has("take_item"):
		var qty: int = int(effect.get("qty", 1))
		GameManager.remove_item(effect["take_item"], qty)
		DebugLog.info("DialogueManager: take_item %s x%d" % [effect["take_item"], qty])
	if effect.has("give_gold"):
		var amount: int = int(effect["give_gold"])
		GameManager.gold += amount
		GameManager.inventory_changed.emit()
		DebugLog.info("DialogueManager: give_gold %d" % amount)
	if effect.has("set_flag"):
		GameManager.set_flag(effect["set_flag"])
		DebugLog.info("DialogueManager: set_flag %s" % effect["set_flag"])
	if effect.has("start_quest"):
		GameManager.start_quest(effect["start_quest"])
		DebugLog.info("DialogueManager: start_quest %s" % effect["start_quest"])
	if effect.has("open_shop"):
		DebugLog.info("DialogueManager: open_shop '%s' (not yet implemented)" % effect["open_shop"])
