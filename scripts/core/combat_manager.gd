extends Node
class_name CombatManager

signal encounter_started()
signal turn_resolved(actor_name: String, action_name: String, result: String)
signal encounter_ended(victory: bool)
signal combat_log_entry(text: String)

var encounter_active: bool = false
var enemies: Array[Dictionary] = []
var turn_order: Array[Dictionary] = []
var pending_player_actions: Array[Dictionary] = []
var waiting_for_player_input: bool = false
var current_command_char_idx: int = 0

func start_encounter(enemy_ids: Array[String]) -> void:
	enemies.clear()
	for eid in enemy_ids:
		var record: Dictionary = DataRegistry.get_record(eid)
		if record.is_empty():
			DebugLog.warn("CombatManager: Unknown enemy '%s'" % eid)
			continue
		var enemy: Dictionary = {
			"id": eid,
			"name": record.get("name", eid),
			"hp": int(record.get("hp", 10)),
			"max_hp": int(record.get("hp", 10)),
			"mp": int(record.get("mp", 0)),
			"strength": int(record.get("strength", 5)),
			"defense": int(record.get("defense", 2)),
			"agility": int(record.get("agility", 5)),
			"xp_reward": int(record.get("xp_reward", 10)),
			"gold_min": int(record.get("gold_reward", {}).get("min", 5)),
			"gold_max": int(record.get("gold_reward", {}).get("max", 10)),
			"loot_table": record.get("loot_table", []),
			"defending": false,
		}
		enemies.append(enemy)
	if enemies.is_empty():
		DebugLog.warn("CombatManager: No valid enemies for encounter")
		return
	encounter_active = true
	pending_player_actions.clear()
	current_command_char_idx = 0
	waiting_for_player_input = false
	_log("Encounter started! Enemies: %s" % _enemy_names())
	_build_turn_order()
	GameManager.current_state = GameManager.GameState.COMBAT
	encounter_started.emit()

func _enemy_names() -> String:
	var names: PackedStringArray = []
	for e in enemies:
		names.append(e["name"])
	return ", ".join(names)

func _build_turn_order() -> void:
	turn_order.clear()
	for i in range(GameManager.party.size()):
		var member: Dictionary = GameManager.party[i]
		if member["hp"] > 0:
			turn_order.append({
				"type": "party",
				"index": i,
				"name": member["name"],
				"agility": member["agility"],
			})
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if enemy["hp"] > 0:
			turn_order.append({
				"type": "enemy",
				"index": i,
				"name": enemy["name"],
				"agility": enemy["agility"],
			})
	turn_order.sort_custom(func(a, b): return a["agility"] > b["agility"])
	DebugLog.info("CombatManager: Turn order: %s" % _turn_order_names())

func _turn_order_names() -> String:
	var names: PackedStringArray = []
	for t in turn_order:
		names.append("%s(%d)" % [t["name"], t["agility"]])
	return " > ".join(names)

func begin_player_command_phase() -> void:
	pending_player_actions.clear()
	current_command_char_idx = 0
	clear_defending()
	_find_next_living_party_member()

func _find_next_living_party_member() -> void:
	while current_command_char_idx < GameManager.party.size():
		var member: Dictionary = GameManager.party[current_command_char_idx]
		if member["hp"] > 0:
			waiting_for_player_input = true
			return
		current_command_char_idx += 1
	waiting_for_player_input = false
	_resolve_all_turns()

func submit_player_action(action_type: String, params: Dictionary = {}) -> void:
	if not waiting_for_player_input:
		return
	var member: Dictionary = GameManager.party[current_command_char_idx]
	var action_entry: Dictionary = {
		"type": "party",
		"index": current_command_char_idx,
		"name": member["name"],
		"action_type": action_type,
		"params": params,
	}
	pending_player_actions.append(action_entry)
	_log("%s chooses %s" % [member["name"], action_type])
	current_command_char_idx += 1
	_find_next_living_party_member()

func _resolve_all_turns() -> void:
	var all_actions: Array[Dictionary] = []
	for entry in pending_player_actions:
		all_actions.append(entry)
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if enemy["hp"] > 0:
			all_actions.append(_enemy_decide_action(i))
	all_actions.sort_custom(func(a, b):
		var a_agi: int = _get_agility(a)
		var b_agi: int = _get_agility(b)
		return a_agi > b_agi
	)
	for action in all_actions:
		if action["type"] == "party":
			_resolve_party_action(action)
		else:
			_resolve_enemy_action(action)
		if _check_combat_end() != "ongoing":
			break
	var result: String = _check_combat_end()
	if result == "victory":
		_end_encounter(true)
	elif result == "defeat":
		_end_encounter(false)
	else:
		_build_turn_order()
		begin_player_command_phase()

func _get_agility(action: Dictionary) -> int:
	if action["type"] == "party":
		var member: Dictionary = GameManager.party[action["index"]]
		return member.get("agility", 5)
	else:
		var enemy: Dictionary = enemies[action["index"]]
		return enemy.get("agility", 5)

func _enemy_decide_action(enemy_idx: int) -> Dictionary:
	var enemy: Dictionary = enemies[enemy_idx]
	var target_idx: int = _find_lowest_hp_party_member()
	return {
		"type": "enemy",
		"index": enemy_idx,
		"name": enemy["name"],
		"action_type": "attack",
		"params": { "target": target_idx },
	}

func _find_lowest_hp_party_member() -> int:
	var best_idx: int = -1
	var best_hp: int = 999999
	for i in range(GameManager.party.size()):
		var member: Dictionary = GameManager.party[i]
		if member["hp"] > 0 and member["hp"] < best_hp:
			best_hp = member["hp"]
			best_idx = i
	return best_idx

func _resolve_party_action(action: Dictionary) -> void:
	var char_idx: int = action["index"]
	var member: Dictionary = GameManager.party[char_idx]
	if member["hp"] <= 0:
		return
	match action["action_type"]:
		"attack":
			var target_idx: int = action["params"].get("target", 0)
			if target_idx < 0 or target_idx >= enemies.size():
				return
			var enemy: Dictionary = enemies[target_idx]
			if enemy["hp"] <= 0:
				_log("%s attacks %s but they are already dead" % [member["name"], enemy["name"]])
				return
			var dmg: int = _calculate_physical_damage(member, enemy)
			enemy["hp"] = maxi(enemy["hp"] - dmg, 0)
			var msg: String = "%s attacks %s for %d damage" % [member["name"], enemy["name"], dmg]
			if enemy["hp"] <= 0:
				msg += " — %s defeated!" % enemy["name"]
			_log(msg)
			turn_resolved.emit(member["name"], "attack", msg)
		"defend":
			member["defending"] = true
			_log("%s takes a defensive stance" % member["name"])
			turn_resolved.emit(member["name"], "defend", "defending")
		"magic":
			var spell_id: String = action["params"].get("spell_id", "")
			var target_idx: int = action["params"].get("target", 0)
			var spell_record: Dictionary = DataRegistry.get_record(spell_id)
			if spell_record.is_empty():
				_log("%s tries to cast an unknown spell" % member["name"])
				return
			var mp_cost: int = int(spell_record.get("mp_cost", 0))
			if member["mp"] < mp_cost:
				_log("%s doesn't have enough MP for %s" % [member["name"], spell_record.get("name", spell_id)])
				return
			var school: String = spell_record.get("school", "")
			if school == "destruction" or school == "holy":
				if target_idx < 0 or target_idx >= enemies.size():
					return
				var enemy: Dictionary = enemies[target_idx]
				if enemy["hp"] <= 0:
					return
				member["mp"] -= mp_cost
				var spell_dmg: int = _calculate_spell_damage(member, spell_record)
				enemy["hp"] = maxi(enemy["hp"] - spell_dmg, 0)
				var msg: String = "%s casts %s on %s for %d damage" % [member["name"], spell_record.get("name", spell_id), enemy["name"], spell_dmg]
				if enemy["hp"] <= 0:
					msg += " — %s defeated!" % enemy["name"]
				_log(msg)
				turn_resolved.emit(member["name"], "magic", msg)
			elif school == "restoration":
				var heal_min: int = int(spell_record.get("heal_min", 10))
				var heal_max: int = int(spell_record.get("heal_max", 20))
				var heal_amount: int = randi_range(heal_min, heal_max)
				var ally_idx: int = action["params"].get("target", char_idx)
				if ally_idx >= 0 and ally_idx < GameManager.party.size():
					member["mp"] -= mp_cost
					GameManager.heal_party_member(ally_idx, heal_amount)
					var ally_name: String = GameManager.party[ally_idx]["name"]
					_log("%s casts %s on %s, restoring %d HP" % [member["name"], spell_record.get("name", spell_id), ally_name, heal_amount])
					turn_resolved.emit(member["name"], "magic", "heal")
		"item":
			var item_id: String = action["params"].get("item_id", "")
			var item_record: Dictionary = DataRegistry.get_record(item_id)
			if item_record.is_empty():
				return
			var effect: String = item_record.get("effect", "")
			var val_min: int = int(item_record.get("value_min", item_record.get("value", 0)))
			var val_max: int = int(item_record.get("value_max", item_record.get("value", 0)))
			var amount: int = randi_range(val_min, val_max) if val_max > 0 else val_min
			if effect == "heal":
				var target: int = action["params"].get("target", char_idx)
				GameManager.heal_party_member(target, amount)
				GameManager.remove_item(item_id, 1)
				var target_name: String = GameManager.party[target]["name"]
				_log("%s uses %s on %s, restoring %d HP" % [member["name"], item_record.get("name", item_id), target_name, amount])
				turn_resolved.emit(member["name"], "item", "heal")
			elif effect == "restore_mp":
				var target: int = action["params"].get("target", char_idx)
				if target >= 0 and target < GameManager.party.size():
					var m: Dictionary = GameManager.party[target]
					m["mp"] = mini(m["mp"] + amount, m["max_mp"])
					GameManager.remove_item(item_id, 1)
					GameManager.party_changed.emit()
					_log("%s uses %s on %s, restoring %d MP" % [member["name"], item_record.get("name", item_id), m["name"], amount])
					turn_resolved.emit(member["name"], "item", "restore_mp")
		"flee":
			var party_agi: int = 0
			for m in GameManager.party:
				if m["hp"] > 0:
					party_agi += m["agility"]
			var enemy_agi: int = 0
			for e in enemies:
				if e["hp"] > 0:
					enemy_agi += e["agility"]
			var flee_chance: float = float(party_agi) / float(party_agi + enemy_agi) if (party_agi + enemy_agi) > 0 else 0.5
			if randf() < flee_chance:
				_log("Successfully fled from combat!")
				_end_encounter(false)
			else:
				_log("Failed to flee!")
				turn_resolved.emit(member["name"], "flee", "failed")

func _resolve_enemy_action(action: Dictionary) -> void:
	var enemy_idx: int = action["index"]
	var enemy: Dictionary = enemies[enemy_idx]
	if enemy["hp"] <= 0:
		return
	var target_idx: int = action["params"].get("target", 0)
	if target_idx < 0 or target_idx >= GameManager.party.size():
		return
	var target: Dictionary = GameManager.party[target_idx]
	if target["hp"] <= 0:
		target_idx = _find_lowest_hp_party_member()
		if target_idx < 0:
			return
		target = GameManager.party[target_idx]
	var dmg: int = _calculate_enemy_damage(enemy, target)
	target["hp"] = maxi(target["hp"] - dmg, 0)
	GameManager.party_changed.emit()
	var msg: String = "%s attacks %s for %d damage" % [enemy["name"], target["name"], dmg]
	if target["hp"] <= 0:
		msg += " — %s falls!" % target["name"]
	_log(msg)
	turn_resolved.emit(enemy["name"], "attack", msg)

func _calculate_physical_damage(attacker: Dictionary, defender: Dictionary) -> int:
	var weapon_mult: float = 1.0
	var weapon_id: String = attacker.get("equipment", {}).get("main_hand", "")
	if not weapon_id.is_empty():
		var weapon_record: Dictionary = DataRegistry.get_record(weapon_id)
		if not weapon_record.is_empty():
			var dmg_min: int = int(weapon_record.get("damage_min", 1))
			var dmg_max: int = int(weapon_record.get("damage_max", 3))
			weapon_mult = float(dmg_min + dmg_max) / 2.0
	var base: float = attacker["strength"] * weapon_mult
	var armor_mult: float = 1.0
	var armor_id: String = attacker.get("equipment", {}).get("body", "")
	if not armor_id.is_empty():
		var armor_record: Dictionary = DataRegistry.get_record(armor_id)
		if not armor_record.is_empty():
			armor_mult = float(armor_record.get("defense", 0)) * 0.5
	var reduction: float = defender["defense"] * armor_mult
	var raw: float = base - reduction + randf_range(-2, 2)
	var defending_mult: float = 0.5 if defender.get("defending", false) else 1.0
	var final_dmg: int = int(raw * defending_mult)
	var agi: int = attacker.get("agility", 5)
	var crit_chance: float = agi * 0.005
	if randf() < crit_chance:
		final_dmg = int(final_dmg * 1.5)
		_log("Critical hit!")
	return maxi(final_dmg, 1)

func _calculate_spell_damage(attacker: Dictionary, spell_record: Dictionary) -> int:
	var dmg_min: int = int(spell_record.get("damage_min", 5))
	var dmg_max: int = int(spell_record.get("damage_max", 10))
	var base: float = randf_range(dmg_min, dmg_max)
	var energy_mult: float = 1.0 + attacker["energy"] * 0.05
	return int(base * energy_mult)

func _calculate_enemy_damage(enemy: Dictionary, target: Dictionary) -> int:
	var base: float = enemy["strength"]
	var armor_def: float = 0.0
	var body_id: String = target.get("equipment", {}).get("body", "")
	if not body_id.is_empty():
		var body_record: Dictionary = DataRegistry.get_record(body_id)
		if not body_record.is_empty():
			armor_def = float(body_record.get("defense", 0))
	var shield_def: float = 0.0
	var shield_id: String = target.get("equipment", {}).get("off_hand", "")
	if not shield_id.is_empty():
		var shield_record: Dictionary = DataRegistry.get_record(shield_id)
		if not shield_record.is_empty():
			shield_def = float(shield_record.get("defense", 0))
	var reduction: float = (target["defense"] + armor_def + shield_def) * 0.5
	var raw: float = base - reduction + randf_range(-2, 2)
	var defending_mult: float = 0.5 if target.get("defending", false) else 1.0
	return maxi(int(raw * defending_mult), 1)

func _check_combat_end() -> String:
	var party_alive: bool = false
	for m in GameManager.party:
		if m["hp"] > 0:
			party_alive = true
			break
	if not party_alive:
		return "defeat"
	var enemies_alive: bool = false
	for e in enemies:
		if e["hp"] > 0:
			enemies_alive = true
			break
	if not enemies_alive:
		return "victory"
	return "ongoing"

func _end_encounter(victory: bool) -> void:
	if not encounter_active:
		return
	encounter_active = false
	if victory:
		var total_xp: int = 0
		var total_gold: int = 0
		var loot_items: Array[String] = []
		for e in enemies:
			total_xp += e["xp_reward"]
			total_gold += randi_range(e["gold_min"], e["gold_max"])
			for loot_id in e["loot_table"]:
				if randf() < 0.1:
					loot_items.append(loot_id)
		var alive_count: int = 0
		for m in GameManager.party:
			if m["hp"] > 0:
				alive_count += 1
		if alive_count > 0:
			var xp_each: int = total_xp / alive_count
			for m in GameManager.party:
				if m["hp"] > 0:
					m["xp"] += xp_each
					_check_level_up(m)
		GameManager.gold += total_gold
		for item_id in loot_items:
			GameManager.add_item(item_id, 1)
		_log("Victory! Gained %d XP, %d gold" % [total_xp, total_gold])
		if loot_items.size() > 0:
			_log("Found items: %s" % ", ".join(loot_items))
	else:
		_log("Defeat... The party has fallen.")
	GameManager.party_changed.emit()
	GameManager.inventory_changed.emit()
	encounter_ended.emit(victory)

func _check_level_up(member: Dictionary) -> void:
	while member["xp"] >= member["xp_to_next"]:
		member["xp"] -= member["xp_to_next"]
		member["level"] += 1
		member["xp_to_next"] = int(member["xp_to_next"] * 1.5)
		var class_record: Dictionary = DataRegistry.get_record(member.get("class_id", ""))
		if class_record.is_empty():
			continue
		var growth: Dictionary = class_record.get("stat_growth", {})
		if growth.is_empty():
			continue
		var old_hp: int = member["max_hp"]
		var old_mp: int = member["max_mp"]
		member["hp"] += int(growth.get("hp", 1))
		member["max_hp"] += int(growth.get("hp", 1))
		member["mp"] += int(growth.get("mp", 0))
		member["max_mp"] += int(growth.get("mp", 0))
		member["strength"] += int(growth.get("strength", 1))
		member["defense"] += int(growth.get("defense", 1))
		member["vitality"] += int(growth.get("vitality", 1))
		member["energy"] += int(growth.get("energy", 1))
		member["agility"] += int(growth.get("agility", 1))
		member["luck"] += int(growth.get("luck", 1))
		_log("%s leveled up to %d! HP+%d MP+%d" % [member["name"], member["level"], member["max_hp"] - old_hp, member["max_mp"] - old_mp])
	GameManager.party_changed.emit()

func get_living_party_member_count() -> int:
	var count: int = 0
	for m in GameManager.party:
		if m["hp"] > 0:
			count += 1
	return count

func get_living_enemy_count() -> int:
	var count: int = 0
	for e in enemies:
		if e["hp"] > 0:
			count += 1
	return count

func get_party_member_spells(char_idx: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if char_idx < 0 or char_idx >= GameManager.party.size():
		return results
	var member: Dictionary = GameManager.party[char_idx]
	for spell_id in member.get("spells", []):
		var record: Dictionary = DataRegistry.get_record(spell_id)
		if not record.is_empty():
			results.append(record)
	return results

func get_party_consumables() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in GameManager.get_inventory():
		var record: Dictionary = DataRegistry.get_record(entry["id"])
		if not record.is_empty() and record.get("type", "") == "consumable":
			var item: Dictionary = record.duplicate()
			item["quantity"] = entry["quantity"]
			results.append(item)
	return results

func clear_defending() -> void:
	for m in GameManager.party:
		m.erase("defending")

func _log(text: String) -> void:
	combat_log_entry.emit(text)
	DebugLog.info("Combat: %s" % text)
