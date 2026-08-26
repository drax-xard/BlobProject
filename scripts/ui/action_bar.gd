extends HBoxContainer

signal action_button_pressed(action: Action)

@onready var turn_manager: Node = null

var _stair_button: Button = null
var _on_stairs: bool = false

func _ready() -> void:
	turn_manager = get_tree().current_scene.get_node_or_null("TurnManager")
	_build_buttons()
	_connect_grid_world()

func _connect_grid_world() -> void:
	var scene: Node = get_tree().current_scene
	if not scene:
		return
	var viewport: SubViewportContainer = scene.find_child("ViewportFrame", true, false)
	if not viewport:
		return
	var sub_viewport: SubViewport = viewport.get_node_or_null("SubViewport")
	if not sub_viewport:
		return
	var world: Node = sub_viewport.get_node_or_null("World")
	if world and world.has_signal("player_stair_state"):
		world.player_stair_state.connect(_on_player_stair_state)

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

	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 8
	add_child(sep)

	_stair_button = Button.new()
	_stair_button.text = ">>"
	_stair_button.tooltip_text = "Use Stairs"
	_stair_button.custom_minimum_size = Vector2(50, 50)
	_stair_button.visible = false
	_stair_button.pressed.connect(_on_stair_pressed)
	add_child(_stair_button)

	var sep2 := VSeparator.new()
	sep2.custom_minimum_size.x = 8
	add_child(sep2)

	var inv_btn := Button.new()
	inv_btn.text = "I"
	inv_btn.tooltip_text = "Inventory"
	inv_btn.custom_minimum_size = Vector2(50, 50)
	inv_btn.pressed.connect(_on_inventory_pressed)
	add_child(inv_btn)

func _on_player_stair_state(is_on_stairs: bool, _stair_type: String) -> void:
	_on_stairs = is_on_stairs
	if _stair_button:
		_stair_button.visible = is_on_stairs
		if is_on_stairs:
			_stair_button.text = ">>"
			_stair_button.tooltip_text = "Use %s" % _stair_type.capitalize()

func _on_stair_pressed() -> void:
	if not _on_stairs:
		return
	var scene: Node = get_tree().current_scene
	if not scene:
		return
	var viewport: SubViewportContainer = scene.find_child("ViewportFrame", true, false)
	if not viewport:
		return
	var sub_viewport: SubViewport = viewport.get_node_or_null("SubViewport")
	if not sub_viewport:
		return
	var world: Node = sub_viewport.get_node_or_null("World")
	if world:
		world.use_stair()

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

func _on_inventory_pressed() -> void:
	var state := GameManager.current_state
	if state == GameManager.GameState.EXPLORING:
		GameManager.current_state = GameManager.GameState.INVENTORY
	elif state == GameManager.GameState.INVENTORY:
		GameManager.current_state = GameManager.GameState.EXPLORING
