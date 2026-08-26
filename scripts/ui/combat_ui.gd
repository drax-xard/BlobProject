extends Control

var _combat_manager: CombatManager
var _enemy_container: VBoxContainer
var _enemy_hp_bars: Array[Dictionary] = []
var _log_container: VBoxContainer
var _log_scroll: ScrollContainer
var _command_panel: VBoxContainer
var _command_buttons: HBoxContainer
var _target_panel: VBoxContainer
var _target_buttons: HBoxContainer
var _result_panel: VBoxContainer
var _result_label: Label
var _info_label: Label

var _selecting_target: bool = false
var _pending_action_type: String = ""
var _pending_action_params: Dictionary = {}
var _combat_victory: bool = false

func _ready() -> void:
	visible = false
	_combat_manager = _find_combat_manager()
	if _combat_manager:
		_combat_manager.encounter_started.connect(_on_encounter_started)
		_combat_manager.encounter_ended.connect(_on_encounter_ended)
		_combat_manager.turn_resolved.connect(_on_turn_resolved)
		_combat_manager.combat_log_entry.connect(_on_log_entry)
	set_process_input(true)

func _find_combat_manager() -> CombatManager:
	var scene: Node = get_tree().current_scene
	if scene:
		var cm: Node = scene.get_node_or_null("CombatManager")
		if cm is CombatManager:
			return cm
	return null

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_enemy_hp_bars.clear()

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var title := Label.new()
	title.text = "COMBAT"
	title.add_theme_font_size_override("font_size", 20)
	root_vbox.add_child(title)

	var enemy_section := VBoxContainer.new()
	enemy_section.add_theme_constant_override("separation", 4)
	root_vbox.add_child(enemy_section)

	var enemy_label := Label.new()
	enemy_label.text = "Enemies:"
	enemy_label.add_theme_font_size_override("font_size", 14)
	enemy_section.add_child(enemy_label)

	_enemy_container = VBoxContainer.new()
	_enemy_container.add_theme_constant_override("separation", 4)
	enemy_section.add_child(_enemy_container)

	var sep1 := HSeparator.new()
	root_vbox.add_child(sep1)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.custom_minimum_size.y = 120
	root_vbox.add_child(_log_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log_container)

	var sep2 := HSeparator.new()
	root_vbox.add_child(sep2)

	_info_label = Label.new()
	_info_label.text = ""
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_info_label)

	_command_panel = VBoxContainer.new()
	_command_panel.add_theme_constant_override("separation", 6)
	root_vbox.add_child(_command_panel)

	_command_buttons = HBoxContainer.new()
	_command_buttons.add_theme_constant_override("separation", 8)
	_command_panel.add_child(_command_buttons)

	_target_panel = VBoxContainer.new()
	_target_panel.visible = false
	_target_panel.add_theme_constant_override("separation", 6)
	root_vbox.add_child(_target_panel)

	var target_label := Label.new()
	target_label.text = "Select target:"
	target_label.add_theme_font_size_override("font_size", 14)
	_target_panel.add_child(target_label)

	_target_buttons = HBoxContainer.new()
	_target_buttons.add_theme_constant_override("separation", 8)
	_target_panel.add_child(_target_buttons)

	_result_panel = VBoxContainer.new()
	_result_panel.visible = false
	_result_panel.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_result_panel)

	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_panel.add_child(_result_label)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(150, 40)
	continue_btn.pressed.connect(_on_continue_pressed)
	_result_panel.add_child(continue_btn)

func _on_encounter_started() -> void:
	if not _enemy_container:
		_build_ui()
	_clear_log()
	_refresh_enemy_display()
	_result_panel.visible = false
	_target_panel.visible = false
	visible = true
	_start_command_phase()

func _on_encounter_ended(victory: bool) -> void:
	_combat_victory = victory
	_result_panel.visible = true
	_command_panel.visible = false
	_target_panel.visible = false
	if victory:
		_result_label.text = "VICTORY!"
		_info_label.text = _get_reward_summary()
	else:
		_result_label.text = "DEFEAT"
		_info_label.text = "The party has fallen..."

func _get_reward_summary() -> String:
	var total_xp: int = 0
	var total_gold: int = 0
	if _combat_manager:
		for e in _combat_manager.enemies:
			total_xp += e["xp_reward"]
			total_gold += e["gold_min"] + (e["gold_max"] - e["gold_min"]) / 2
	return "Gained %d XP, %d gold" % [total_xp, total_gold]

func _on_continue_pressed() -> void:
	visible = false
	if _combat_victory:
		GameManager.current_state = GameManager.GameState.EXPLORING
	else:
		GameManager.current_state = GameManager.GameState.MENU

func _refresh_enemy_display() -> void:
	for child in _enemy_container.get_children():
		child.queue_free()
	_enemy_hp_bars.clear()
	if not _combat_manager:
		return
	for i in range(_combat_manager.enemies.size()):
		var enemy: Dictionary = _combat_manager.enemies[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_enemy_container.add_child(row)

		var name_label := Label.new()
		name_label.text = enemy["name"]
		name_label.custom_minimum_size.x = 120
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(150, 20)
		hp_bar.max_value = enemy["max_hp"]
		hp_bar.value = enemy["hp"]
		hp_bar.show_percentage = false
		row.add_child(hp_bar)

		var hp_label := Label.new()
		hp_label.text = "%d/%d" % [enemy["hp"], enemy["max_hp"]]
		hp_label.add_theme_font_size_override("font_size", 13)
		hp_label.custom_minimum_size.x = 70
		row.add_child(hp_label)

		_enemy_hp_bars.append({
			"bar": hp_bar,
			"label": hp_label,
			"index": i,
		})

func _update_enemy_hp() -> void:
	if not _combat_manager:
		return
	for entry in _enemy_hp_bars:
		var idx: int = entry["index"]
		if idx < _combat_manager.enemies.size():
			var enemy: Dictionary = _combat_manager.enemies[idx]
			entry["bar"].value = enemy["hp"]
			entry["label"].text = "%d/%d" % [enemy["hp"], enemy["max_hp"]]
			if enemy["hp"] <= 0:
				entry["bar"].modulate = Color(0.5, 0.5, 0.5)
				entry["label"].modulate = Color(0.5, 0.5, 0.5)

func _start_command_phase() -> void:
	if not _combat_manager:
		return
	_command_panel.visible = true
	_target_panel.visible = false
	_combat_manager.begin_player_command_phase()
	_show_current_char_commands()

func _show_current_char_commands() -> void:
	if not _combat_manager or not _combat_manager.waiting_for_player_input:
		return
	for child in _command_buttons.get_children():
		child.queue_free()
	var char_idx: int = _combat_manager.current_command_char_idx
	var member: Dictionary = GameManager.party[char_idx]
	_info_label.text = "%s's turn (HP: %d/%d, MP: %d/%d)" % [
		member["name"], member["hp"], member["max_hp"],
		member["mp"], member["max_mp"]
	]

	var attack_btn := Button.new()
	attack_btn.text = "Attack"
	attack_btn.custom_minimum_size = Vector2(80, 36)
	attack_btn.pressed.connect(_on_attack_pressed)
	_command_buttons.add_child(attack_btn)

	var spells: Array[Dictionary] = _combat_manager.get_party_member_spells(char_idx)
	if spells.size() > 0:
		var magic_btn := Button.new()
		magic_btn.text = "Magic"
		magic_btn.custom_minimum_size = Vector2(80, 36)
		magic_btn.pressed.connect(_on_magic_pressed)
		_command_buttons.add_child(magic_btn)

	var consumables: Array[Dictionary] = _combat_manager.get_party_consumables()
	if consumables.size() > 0:
		var item_btn := Button.new()
		item_btn.text = "Item"
		item_btn.custom_minimum_size = Vector2(80, 36)
		item_btn.pressed.connect(_on_item_pressed)
		_command_buttons.add_child(item_btn)

	var defend_btn := Button.new()
	defend_btn.text = "Defend"
	defend_btn.custom_minimum_size = Vector2(80, 36)
	defend_btn.pressed.connect(_on_defend_pressed)
	_command_buttons.add_child(defend_btn)

	var flee_btn := Button.new()
	flee_btn.text = "Flee"
	flee_btn.custom_minimum_size = Vector2(80, 36)
	flee_btn.pressed.connect(_on_flee_pressed)
	_command_buttons.add_child(flee_btn)

func _on_attack_pressed() -> void:
	_pending_action_type = "attack"
	_pending_action_params = {}
	_show_target_selection(false)

func _on_magic_pressed() -> void:
	if not _combat_manager:
		return
	var char_idx: int = _combat_manager.current_command_char_idx
	var spells: Array[Dictionary] = _combat_manager.get_party_member_spells(char_idx)
	if spells.is_empty():
		return
	if spells.size() == 1:
		if not _validate_magic_spell(spells[0]):
			return
		_pending_action_type = "magic"
		_pending_action_params = { "spell_id": spells[0]["id"] }
		if spells[0].get("target", "") == "single_ally":
			_show_target_selection(true)
		else:
			_show_target_selection(false)
		return
	_show_spell_selection(spells)

func _show_spell_selection(spells: Array[Dictionary]) -> void:
	for child in _target_buttons.get_children():
		child.queue_free()
	_target_panel.visible = true
	for spell in spells:
		var btn := Button.new()
		btn.text = "%s (MP: %d)" % [spell.get("name", spell["id"]), int(spell.get("mp_cost", 0))]
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(_on_spell_selected.bind(spell))
		_target_buttons.add_child(btn)

func _on_spell_selected(spell: Dictionary) -> void:
	_pending_action_type = "magic"
	_pending_action_params = { "spell_id": spell["id"] }
	if spell.get("target", "") == "single_ally":
		_show_target_selection(true)
	else:
		_show_target_selection(false)

func _validate_magic_spell(spell: Dictionary) -> bool:
	if not _combat_manager:
		return false
	var char_idx: int = _combat_manager.current_command_char_idx
	var member: Dictionary = GameManager.party[char_idx]
	var mp_cost: int = int(spell.get("mp_cost", 0))
	if member["mp"] < mp_cost:
		_info_label.text = "%s doesn't have enough MP for %s (%d/%d)" % [member["name"], spell.get("name", ""), member["mp"], mp_cost]
		return false
	return true

func _on_item_pressed() -> void:
	if not _combat_manager:
		return
	var consumables: Array[Dictionary] = _combat_manager.get_party_consumables()
	if consumables.is_empty():
		return
	_show_item_selection(consumables)

func _show_item_selection(items: Array[Dictionary]) -> void:
	for child in _target_buttons.get_children():
		child.queue_free()
	_target_panel.visible = true
	for item in items:
		var btn := Button.new()
		btn.text = "%s (x%d)" % [item.get("name", item["id"]), item.get("quantity", 0)]
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(_on_item_selected.bind(item))
		_target_buttons.add_child(btn)

func _on_item_selected(item: Dictionary) -> void:
	_pending_action_type = "item"
	_pending_action_params = { "item_id": item["id"] }
	var effect: String = item.get("effect", "")
	if effect == "heal" or effect == "restore_mp":
		_show_target_selection(true)
	else:
		_submit_pending_action()

func _on_defend_pressed() -> void:
	if not _combat_manager:
		return
	_combat_manager.submit_player_action("defend")
	_target_panel.visible = false
	_show_current_char_commands()

func _on_flee_pressed() -> void:
	if not _combat_manager:
		return
	_combat_manager.submit_player_action("flee")
	_target_panel.visible = false
	_show_current_char_commands()

func _show_target_selection(allow_ally: bool) -> void:
	for child in _target_buttons.get_children():
		child.queue_free()
	_target_panel.visible = true
	if allow_ally:
		for i in range(GameManager.party.size()):
			var member: Dictionary = GameManager.party[i]
			if member["hp"] <= 0:
				continue
			var btn := Button.new()
			btn.text = "%s (HP: %d/%d)" % [member["name"], member["hp"], member["max_hp"]]
			btn.custom_minimum_size = Vector2(140, 36)
			btn.pressed.connect(_on_target_selected.bind(i))
			_target_buttons.add_child(btn)
	else:
		if not _combat_manager:
			return
		for i in range(_combat_manager.enemies.size()):
			var enemy: Dictionary = _combat_manager.enemies[i]
			if enemy["hp"] <= 0:
				continue
			var btn := Button.new()
			btn.text = "%s (HP: %d/%d)" % [enemy["name"], enemy["hp"], enemy["max_hp"]]
			btn.custom_minimum_size = Vector2(140, 36)
			btn.pressed.connect(_on_target_selected.bind(i))
			_target_buttons.add_child(btn)

func _on_target_selected(target_idx: int) -> void:
	_pending_action_params["target"] = target_idx
	_submit_pending_action()

func _submit_pending_action() -> void:
	if not _combat_manager:
		return
	_target_panel.visible = false
	_combat_manager.submit_player_action(_pending_action_type, _pending_action_params)
	_pending_action_type = ""
	_pending_action_params = {}
	_show_current_char_commands()

func _on_turn_resolved(_actor_name: String, _action_name: String, _result: String) -> void:
	_update_enemy_hp()

func _on_log_entry(text: String) -> void:
	if not _log_container:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_container.add_child(label)
	_scroll_log_to_bottom.call_deferred()

func _scroll_log_to_bottom() -> void:
	if _log_scroll and _log_scroll.get_v_scroll_bar():
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

func _clear_log() -> void:
	if _log_container:
		for child in _log_container.get_children():
			child.queue_free()
