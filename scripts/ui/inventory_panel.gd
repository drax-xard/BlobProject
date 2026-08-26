extends Control

var _selected_char: int = 0
var _selected_item_idx: int = -1
var _item_list: Array[Dictionary] = []

var _party_buttons: HBoxContainer
var _stats_container: VBoxContainer
var _equip_container: VBoxContainer
var _inventory_container: VBoxContainer
var _item_actions: HBoxContainer
var _gold_label: Label
var _info_label: Label

func _ready() -> void:
	visible = false
	GameManager.inventory_changed.connect(_refresh)
	GameManager.party_changed.connect(_refresh)
	_build_ui()
	set_process_input(true)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
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

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_party_buttons = HBoxContainer.new()
	_party_buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(_party_buttons)

	var top_label := Label.new()
	top_label.text = "INVENTORY"
	top_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(top_label)

	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.split_offset = 300
	vbox.add_child(hsplit)

	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.custom_minimum_size.x = 280
	left_panel.add_theme_constant_override("separation", 6)
	hsplit.add_child(left_panel)

	var stats_header := Label.new()
	stats_header.text = "Character Stats"
	stats_header.add_theme_font_size_override("font_size", 14)
	left_panel.add_child(stats_header)

	_stats_container = VBoxContainer.new()
	_stats_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_stats_container)

	var equip_header := Label.new()
	equip_header.text = "Equipment"
	equip_header.add_theme_font_size_override("font_size", 14)
	left_panel.add_child(equip_header)

	_equip_container = VBoxContainer.new()
	_equip_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_equip_container)

	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 6)
	hsplit.add_child(right_panel)

	var inv_header := HBoxContainer.new()
	right_panel.add_child(inv_header)

	var inv_label := Label.new()
	inv_label.text = "Items"
	inv_label.add_theme_font_size_override("font_size", 14)
	inv_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_header.add_child(inv_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	inv_header.add_child(_gold_label)

	_inventory_container = VBoxContainer.new()
	_inventory_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_inventory_container)

	_item_actions = HBoxContainer.new()
	_item_actions.add_theme_constant_override("separation", 8)
	right_panel.add_child(_item_actions)

	var equip_btn := Button.new()
	equip_btn.text = "[E]quip"
	equip_btn.custom_minimum_size = Vector2(80, 30)
	equip_btn.pressed.connect(_on_equip_pressed)
	_item_actions.add_child(equip_btn)

	var use_btn := Button.new()
	use_btn.text = "[U]se"
	use_btn.custom_minimum_size = Vector2(80, 30)
	use_btn.pressed.connect(_on_use_pressed)
	_item_actions.add_child(use_btn)

	var drop_btn := Button.new()
	drop_btn.text = "[D]rop"
	drop_btn.custom_minimum_size = Vector2(80, 30)
	drop_btn.pressed.connect(_on_drop_pressed)
	_item_actions.add_child(drop_btn)

	_info_label = Label.new()
	_info_label.text = "Press I to close"
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	right_panel.add_child(_info_label)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not event is InputEventKey or not event.pressed:
		return
	if GameManager.current_state != GameManager.GameState.INVENTORY:
		return
	if event.is_action_pressed("open_inventory") or event.is_action_pressed("pause_game"):
		GameManager.current_state = GameManager.GameState.EXPLORING
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			var idx: int = event.keycode - KEY_1
			if idx < GameManager.party.size():
				_selected_char = idx
				_refresh()
		KEY_UP:
			_navigate_item(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_navigate_item(1)
			get_viewport().set_input_as_handled()
		KEY_ENTER:
			_on_equip_pressed()
			get_viewport().set_input_as_handled()
		KEY_U:
			_on_use_pressed()
			get_viewport().set_input_as_handled()
		KEY_D:
			_on_drop_pressed()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	visible = GameManager.current_state == GameManager.GameState.INVENTORY
	if visible and _party_buttons.get_child_count() == 0:
		_build_party_buttons()
		_refresh()

func _build_party_buttons() -> void:
	for child in _party_buttons.get_children():
		child.queue_free()
	for i in range(GameManager.party.size()):
		var member: Dictionary = GameManager.party[i]
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, member["name"]]
		btn.custom_minimum_size = Vector2(120, 30)
		btn.pressed.connect(_on_party_button_pressed.bind(i))
		_party_buttons.add_child(btn)

func _on_party_button_pressed(index: int) -> void:
	_selected_char = index
	_selected_item_idx = -1
	_refresh()

func _navigate_item(direction: int) -> void:
	if _item_list.is_empty():
		return
	_selected_item_idx = clampi(_selected_item_idx + direction, 0, _item_list.size() - 1)
	_refresh_item_selection()

func _refresh() -> void:
	if not visible:
		return
	_build_party_buttons()
	_refresh_stats()
	_refresh_equipment()
	_refresh_inventory()

func _refresh_stats() -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	if _selected_char >= GameManager.party.size():
		return
	var member: Dictionary = GameManager.party[_selected_char]
	var lines := [
		"Name: %s (Lv %d)" % [member["name"], member["level"]],
		"HP: %d / %d" % [member["hp"], member["max_hp"]],
		"MP: %d / %d" % [member["mp"], member["max_mp"]],
		"STR: %d  DEF: %d" % [member["strength"], member["defense"]],
		"VIT: %d  ENR: %d" % [member["vitality"], member["energy"]],
		"AGI: %d  LCK: %d" % [member["agility"], member["luck"]],
	]
	if member.get("spells", []).size() > 0:
		var spell_names: PackedStringArray = []
		for spell_id in member["spells"]:
			var spell: Dictionary = DataRegistry.get_record(spell_id)
			spell_names.append(spell.get("name", spell_id))
		lines.append("Spells: %s" % ", ".join(spell_names))
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 13)
		_stats_container.add_child(lbl)

func _refresh_equipment() -> void:
	for child in _equip_container.get_children():
		child.queue_free()
	if _selected_char >= GameManager.party.size():
		return
	var member: Dictionary = GameManager.party[_selected_char]
	var equipment: Dictionary = member["equipment"]
	var slots := ["main_hand", "off_hand", "head", "body", "legs", "accessory"]
	for slot in slots:
		var hbox := HBoxContainer.new()
		_equip_container.add_child(hbox)
		var slot_label := Label.new()
		slot_label.text = "%s: " % slot.replace("_", " ").capitalize()
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_label.custom_minimum_size.x = 100
		hbox.add_child(slot_label)
		var item_id: String = equipment.get(slot, "")
		if item_id.is_empty():
			var empty_label := Label.new()
			empty_label.text = "(empty)"
			empty_label.add_theme_font_size_override("font_size", 12)
			empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			hbox.add_child(empty_label)
		else:
			var item_record: Dictionary = DataRegistry.get_record(item_id)
			var item_name: String = item_record.get("name", item_id)
			var item_label := Label.new()
			item_label.text = item_name
			item_label.add_theme_font_size_override("font_size", 12)
			hbox.add_child(item_label)

func _refresh_inventory() -> void:
	for child in _inventory_container.get_children():
		child.queue_free()
	_item_list = GameManager.get_inventory()
	_gold_label.text = "Gold: %d" % GameManager.gold
	if _item_list.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_inventory_container.add_child(empty)
		_selected_item_idx = -1
		return
	_selected_item_idx = clampi(_selected_item_idx, 0, _item_list.size() - 1)
	for i in range(_item_list.size()):
		var entry: Dictionary = _item_list[i]
		var item_record: Dictionary = DataRegistry.get_record(entry["id"])
		var item_name: String = item_record.get("name", entry["id"])
		var btn := Button.new()
		btn.text = "%s x%d" % [item_name, entry["quantity"]]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_pressed.bind(i))
		_inventory_container.add_child(btn)
	_refresh_item_selection()
	_update_info_label()

func _refresh_item_selection() -> void:
	for i in range(_inventory_container.get_child_count()):
		var btn: Button = _inventory_container.get_child(i)
		btn.modulate = Color(1, 1, 1) if i != _selected_item_idx else Color(0.8, 1.0, 0.8)
	_update_info_label()

func _update_info_label() -> void:
	if _selected_item_idx < 0 or _selected_item_idx >= _item_list.size():
		_info_label.text = "No item selected"
		return
	var entry: Dictionary = _item_list[_selected_item_idx]
	var item_record: Dictionary = DataRegistry.get_record(entry["id"])
	var desc: String = item_record.get("description", "")
	var value: int = item_record.get("value", 0)
	_info_label.text = "%s  |  Value: %d  |  %s" % [item_record.get("name", ""), value, desc]

func _on_item_pressed(index: int) -> void:
	_selected_item_idx = index
	_refresh_item_selection()

func _on_equip_pressed() -> void:
	if _selected_item_idx < 0 or _selected_item_idx >= _item_list.size():
		return
	var entry: Dictionary = _item_list[_selected_item_idx]
	var item_record: Dictionary = DataRegistry.get_record(entry["id"])
	if item_record.is_empty():
		DebugLog.warn("InventoryPanel: Unknown item '%s'" % entry["id"])
		return
	var item_type: String = item_record.get("type", "")
	if item_type != "weapon" and item_type != "armor":
		_info_label.text = "Cannot equip '%s'" % item_record.get("name", entry["id"])
		return
	var success: bool = GameManager.equip_item(_selected_char, entry["id"])
	if success:
		_selected_item_idx = clampi(_selected_item_idx, 0, _item_list.size() - 1)
		_refresh()

func _on_use_pressed() -> void:
	if _selected_item_idx < 0 or _selected_item_idx >= _item_list.size():
		return
	var entry: Dictionary = _item_list[_selected_item_idx]
	var item_record: Dictionary = DataRegistry.get_record(entry["id"])
	if item_record.is_empty():
		return
	var item_type: String = item_record.get("type", "")
	if item_type != "consumable":
		_info_label.text = "Cannot use '%s'" % item_record.get("name", entry["id"])
		return
	_apply_consumable(entry["id"], item_record)
	_selected_item_idx = clampi(_selected_item_idx, 0, _item_list.size() - 1)
	_refresh()

func _apply_consumable(item_id: String, record: Dictionary) -> void:
	var effect: String = record.get("effect", "")
	var value_min: int = int(record.get("value_min", record.get("value", 0)))
	var value_max: int = int(record.get("value_max", record.get("value", 0)))
	var heal_amount: int = randi_range(value_min, value_max) if value_max > 0 else value_min
	match effect:
		"heal":
			var member: Dictionary = GameManager.party[_selected_char]
			if member["hp"] >= member["max_hp"]:
				_info_label.text = "%s is already at full HP" % member["name"]
				return
			GameManager.heal_party_member(_selected_char, heal_amount)
			GameManager.remove_item(item_id, 1)
			_info_label.text = "%s healed for %d HP" % [member["name"], heal_amount]
		"restore_mp":
			var member: Dictionary = GameManager.party[_selected_char]
			if member["mp"] >= member["max_mp"]:
				_info_label.text = "%s is already at full MP" % member["name"]
				return
			member["mp"] = mini(member["mp"] + heal_amount, member["max_mp"])
			GameManager.remove_item(item_id, 1)
			GameManager.party_changed.emit()
			_info_label.text = "%s restored %d MP" % [member["name"], heal_amount]
		_:
			_info_label.text = "Unknown effect: %s" % effect

func _on_drop_pressed() -> void:
	if _selected_item_idx < 0 or _selected_item_idx >= _item_list.size():
		return
	var entry: Dictionary = _item_list[_selected_item_idx]
	GameManager.remove_item(entry["id"], 1)
	_selected_item_idx = clampi(_selected_item_idx, 0, _item_list.size() - 1)
	_refresh()
