extends HBoxContainer

signal action_button_pressed(action: Action)

@onready var turn_manager: Node = null

func _ready() -> void:
	turn_manager = get_tree().current_scene.get_node_or_null("TurnManager")
	_build_buttons()

func _build_buttons() -> void:
	var button_data := [
		["^", "Forward", Vector2i.UP],
		["v", "Back", Vector2i.DOWN],
		["<", "Turn Left", "turn_left"],
		[">", "Turn Right", "turn_right"],
		["<=", "Strafe L", Vector2i.LEFT],
		["=>", "Strafe R", Vector2i.RIGHT],
	]
	for data in button_data:
		var btn := Button.new()
		btn.text = data[0]
		btn.tooltip_text = data[1]
		btn.custom_minimum_size = Vector2(50, 50)
		btn.pressed.connect(_on_button_pressed.bind(data[2]))
		add_child(btn)

func _on_button_pressed(action_data: Variant) -> void:
	if not turn_manager:
		turn_manager = get_tree().current_scene.get_node_or_null("TurnManager")
	if not turn_manager:
		return
	var action: Action
	if action_data is String:
		action = TurnAction.new(0, TurnAction.LEFT if action_data == "turn_left" else TurnAction.RIGHT)
	elif action_data is Vector2i:
		action = MovementAction.new(0, action_data)
	if action:
		turn_manager.process_ui_action(action)
		action_button_pressed.emit(action)
