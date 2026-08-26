extends PanelContainer

var _portrait: TextureRect
var _npc_name_label: Label
var _text_label: Label
var _choices_container: VBoxContainer
var _typewriter_timer: Timer
var _full_text: String = ""
var _char_index: int = 0
var _typewriter_active: bool = false

func _ready() -> void:
	visible = false
	_build_ui()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_node_changed.connect(_on_node_changed)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

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
	panel.custom_minimum_size = Vector2(700, 300)
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
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(80, 80)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hbox.add_child(_portrait)
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	hbox.add_child(right_col)
	_npc_name_label = Label.new()
	_npc_name_label.add_theme_font_size_override("font_size", 18)
	_npc_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	right_col.add_child(_npc_name_label)
	var sep := HSeparator.new()
	right_col.add_child(sep)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 80)
	_text_label.add_theme_font_size_override("font_size", 15)
	right_col.add_child(_text_label)
	var sep2 := HSeparator.new()
	right_col.add_child(sep2)
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 4)
	right_col.add_child(_choices_container)
	_typewriter_timer = Timer.new()
	_typewriter_timer.wait_time = 0.03
	_typewriter_timer.one_shot = false
	_typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(_typewriter_timer)

func _on_dialogue_started(npc_id: String, npc_name: String) -> void:
	_npc_name_label.text = npc_name
	var record: Dictionary = DataRegistry.get_record(npc_id)
	var portrait_path: String = record.get("portrait", "")
	if not portrait_path.is_empty():
		var tex := ResLoader.load_texture("base", portrait_path)
		if tex:
			_portrait.texture = tex
			_portrait.visible = true
		else:
			_portrait.visible = false
	else:
		_portrait.visible = false
	visible = true

func _on_node_changed(_node_id: String, text: String, choices: Array) -> void:
	_full_text = text
	_char_index = 0
	_typewriter_active = true
	_text_label.visible_characters = 0
	_text_label.text = text
	_typewriter_timer.start()
	_build_choices(choices)

func _on_typewriter_tick() -> void:
	if not _typewriter_active:
		return
	_char_index += 1
	_text_label.visible_characters = _char_index
	if _char_index >= _full_text.length():
		_typewriter_timer.stop()
		_typewriter_active = false

func _build_choices(choices: Array) -> void:
	for child in _choices_container.get_children():
		child.queue_free()
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, choice.get("text", "?")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		_choices_container.add_child(btn)

func _on_choice_pressed(index: int) -> void:
	DialogueManager.select_choice(index)

func _on_dialogue_ended() -> void:
	_typewriter_timer.stop()
	_typewriter_active = false
	visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _typewriter_active:
		return
	if event is InputEventMouseButton and event.pressed:
		_char_index = _full_text.length()
		_text_label.visible_characters = -1
		_typewriter_timer.stop()
		_typewriter_active = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if _char_index < _full_text.length():
			_char_index = _full_text.length()
			_text_label.visible_characters = -1
			_typewriter_timer.stop()
			_typewriter_active = false
			get_viewport().set_input_as_handled()
		else:
			for i in range(1, 10):
				if event.keycode == KEY_0 + i:
					var choices: Array = DialogueManager.get_current_choices()
					if i <= choices.size():
						DialogueManager.select_choice(i - 1)
					get_viewport().set_input_as_handled()
					return
