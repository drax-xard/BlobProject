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
	GameManager.game_loaded.connect(_on_game_loaded)
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PAUSED:
		open_pause_menu()
	elif visible and new_state != GameManager.GameState.PAUSED:
		close()

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
				slot_data.get("party_level", 1), names,
				slot_data.get("floor", 1), slot_data.get("gold", 0),
				slot_data.get("timestamp", "").substr(0, 10),
			]
		hbox.add_child(info_label)
		_info_labels.append(info_label)
		if not slot_data.is_empty():
			var del_btn := Button.new()
			del_btn.text = "X"
			del_btn.custom_minimum_size = Vector2(30, 40)
			del_btn.pressed.connect(_on_delete_pressed.bind(i))
			hbox.add_child(del_btn)

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

func open_pause_menu() -> void:
	_mode = "pause"
	_title_label.text = "Paused"
	_action_panel.visible = false
	_slot_list.visible = false
	_build_pause_buttons()
	visible = true

func _build_pause_buttons() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.pressed.connect(_on_resume_pressed)
	_slot_list.add_child(resume_btn)
	var save_btn := Button.new()
	save_btn.text = "Save Game"
	save_btn.custom_minimum_size = Vector2(200, 40)
	save_btn.pressed.connect(_on_pause_save_pressed)
	_slot_list.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(200, 40)
	load_btn.pressed.connect(_on_pause_load_pressed)
	_slot_list.add_child(load_btn)

func _on_resume_pressed() -> void:
	GameManager.current_state = GameManager.GameState.EXPLORING

func _on_pause_save_pressed() -> void:
	open_save_mode()

func _on_pause_load_pressed() -> void:
	open_load_mode()

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

func _on_delete_pressed(slot: int) -> void:
	_selected_slot = slot
	_show_confirm("Delete", "Delete save in Slot %d?" % (slot + 1))

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
			_action_panel.visible = false
			_slot_list.visible = true
			_build_slot_list()
		"load":
			SaveManager.load_game(_selected_slot)
			GameManager.game_event.emit("Game loaded from Slot %d" % (_selected_slot + 1), Color(0.5, 1.0, 0.5))
			close()
		"delete":
			SaveManager.delete_save(_selected_slot)
			GameManager.game_event.emit("Deleted save Slot %d" % (_selected_slot + 1), Color(1.0, 0.5, 0.5))
			_action_panel.visible = false
			_slot_list.visible = true
			_build_slot_list()
	_selected_slot = -1

func _on_cancel_pressed() -> void:
	_action_panel.visible = false
	_slot_list.visible = true
	_selected_slot = -1

func _on_game_loaded() -> void:
	close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("pause_game"):
		return
	get_viewport().set_input_as_handled()
	match _mode:
		"pause":
			GameManager.current_state = GameManager.GameState.EXPLORING
		"save", "load", "delete":
			open_pause_menu()
