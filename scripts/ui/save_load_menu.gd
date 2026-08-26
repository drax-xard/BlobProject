extends PanelContainer

var _selected_slot: int = -1
var _mode: String = ""
var _slot_buttons: Array[Button] = []
var _info_labels: Array[Label] = []
var _action_panel: VBoxContainer
var _slot_list: VBoxContainer
var _title_label: Label
var _action_title: Label
var _confirm_label: Label

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.anchors_preset = PRESET_FULL_RECT
	add_child(bg)
	var center := CenterContainer.new()
	center.anchors_preset = PRESET_FULL_RECT
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_slot_list)
	_build_slot_list()
	_action_panel = VBoxContainer.new()
	_action_panel.visible = false
	_action_panel.add_theme_constant_override("separation", 8)
	vbox.add_child(_action_panel)
	_action_title = Label.new()
	_action_title.add_theme_font_size_override("font_size", 16)
	_action_panel.add_child(_action_title)
	_confirm_label = Label.new()
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_panel.add_child(_confirm_label)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_action_panel.add_child(btn_row)
	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(100, 36)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(cancel_btn)

func _build_slot_list() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	_slot_buttons.clear()
	_info_labels.clear()
	var slots := SaveManager.get_all_save_slots()
	for i in range(SaveManager.MAX_SLOTS):
		var slot_data: Dictionary = slots[i]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		_slot_list.add_child(hbox)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(60, 40)
		btn.text = "Slot %d" % (i + 1)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		hbox.add_child(btn)
		_slot_buttons.append(btn)
		var info_label := Label.new()
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.add_theme_font_size_override("font_size", 12)
		if slot_data.is_empty():
			info_label.text = "— Empty —"
		else:
			var names: String = ", ".join(slot_data.get("party_names", []))
			info_label.text = "Lv.%d %s | Floor %d | %d gold | %s" % [
				slot_data.get("floor", 1), names,
				slot_data.get("floor", 1), slot_data.get("gold", 0),
				slot_data.get("timestamp", "").substr(0, 10),
			]
		hbox.add_child(info_label)
		_info_labels.append(info_label)

func open_save_mode() -> void:
	_mode = "save"
	_title_label.text = "Save Game"
	_action_panel.visible = false
	_slot_list.visible = true
	_build_slot_list()
	visible = true

func open_load_mode() -> void:
	_mode = "load"
	_title_label.text = "Load Game"
	_action_panel.visible = false
	_slot_list.visible = true
	_build_slot_list()
	visible = true

func close() -> void:
	visible = false
	_selected_slot = -1
	_mode = ""

func _on_slot_pressed(slot: int) -> void:
	_selected_slot = slot
	var has_save := SaveManager.has_save(slot)
	match _mode:
		"save":
			if has_save:
				_show_confirm("Overwrite", "Overwrite save in Slot %d?" % (slot + 1))
			else:
				SaveManager.save_game(slot)
				_build_slot_list()
				GameManager.game_event.emit("Game saved to Slot %d" % (slot + 1), Color(0.5, 1.0, 0.5))
		"load":
			if has_save:
				_show_confirm("Load", "Load game from Slot %d?" % (slot + 1))
			else:
				GameManager.game_event.emit("Slot %d is empty" % (slot + 1), Color(1.0, 0.5, 0.5))

func _show_confirm(title: String, text: String) -> void:
	_slot_list.visible = false
	_action_panel.visible = true
	_action_title.text = title
	_confirm_label.text = text

func _on_confirm_pressed() -> void:
	if _selected_slot < 0:
		return
	match _mode:
		"save":
			SaveManager.save_game(_selected_slot)
			GameManager.game_event.emit("Game saved to Slot %d" % (_selected_slot + 1), Color(0.5, 1.0, 0.5))
		"load":
			SaveManager.load_game(_selected_slot)
			GameManager.game_event.emit("Game loaded from Slot %d" % (_selected_slot + 1), Color(0.5, 1.0, 0.5))
	close()

func _on_cancel_pressed() -> void:
	_action_panel.visible = false
	_slot_list.visible = true
	_selected_slot = -1

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if visible:
			close()
			get_viewport().set_input_as_handled()
		elif GameManager.current_state == GameManager.GameState.EXPLORING:
			open_save_mode()
			get_viewport().set_input_as_handled()
