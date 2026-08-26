extends ScrollContainer

const MAX_MESSAGES: int = 50

var _container: VBoxContainer

func _ready() -> void:
	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.add_theme_constant_override("separation", 2)
	add_child(_container)
	_connect_signals()

func _connect_signals() -> void:
	if GameManager:
		GameManager.party_changed.connect(_on_party_changed)
		GameManager.inventory_changed.connect(_on_inventory_changed)
		GameManager.game_event.connect(_on_game_event)
	var combat_manager: Node = get_tree().current_scene.get_node_or_null("CombatManager")
	if combat_manager:
		if combat_manager.has_signal("combat_log_entry"):
			combat_manager.combat_log_entry.connect(_on_combat_log)
		if combat_manager.has_signal("encounter_started"):
			combat_manager.encounter_started.connect(_on_combat_started)
		if combat_manager.has_signal("encounter_ended"):
			combat_manager.encounter_ended.connect(_on_combat_ended)

func add_message(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = color
	_container.add_child(label)
	while _container.get_child_count() > MAX_MESSAGES:
		var first: Node = _container.get_child(0)
		_container.remove_child(first)
		first.queue_free()
	await get_tree().process_frame
	scroll_vertical = int(get_v_scroll_bar().max_value)

func _on_party_changed() -> void:
	for i in range(GameManager.party.size()):
		var member: Dictionary = GameManager.party[i]
		if member["hp"] <= 0 and member.get("_was_alive", true):
			member["_was_alive"] = false
			add_message("%s has fallen!" % member["name"], Color(1.0, 0.3, 0.3))
		elif member["hp"] > 0 and not member.get("_was_alive", true):
			member["_was_alive"] = true
			add_message("%s has been revived." % member["name"], Color(0.3, 1.0, 0.3))

func _on_inventory_changed() -> void:
	pass

func _on_combat_log(text: String) -> void:
	add_message(text, Color(1.0, 0.9, 0.6))

func _on_combat_started() -> void:
	pass

func _on_combat_ended(_victory: bool) -> void:
	pass

func _on_game_event(text: String, color: Color) -> void:
	add_message(text, color)
