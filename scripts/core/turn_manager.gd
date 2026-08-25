extends Node

signal action_performed(action: Action)
signal turn_processed(turn_number: int)

var is_turn_active: bool = false
var pending_actions: Array[Action] = []

func _input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.EXPLORING:
		return
	if is_turn_active:
		return

	if event is InputEventKey and event.pressed:
		var action := _resolve_input(event)
		if action:
			_process_player_action(action)

func _resolve_input(event: InputEventKey) -> Action:
	if event.is_action_pressed("move_forward"):
		return MovementAction.new(0, Vector2i.UP)
	elif event.is_action_pressed("move_backward"):
		return MovementAction.new(0, Vector2i.DOWN)
	elif event.is_action_pressed("turn_left"):
		return TurnAction.new(0, TurnAction.LEFT)
	elif event.is_action_pressed("turn_right"):
		return TurnAction.new(0, TurnAction.RIGHT)
	elif event.is_action_pressed("strafe_left"):
		return MovementAction.new(0, Vector2i.LEFT)
	elif event.is_action_pressed("strafe_right"):
		return MovementAction.new(0, Vector2i.RIGHT)
	return null

func _process_player_action(action: Action) -> void:
	is_turn_active = true
	var world := get_tree().current_scene.find_child("World", true, true)
	if world:
		action.execute(world)
	action_performed.emit(action)
	GameManager.turn_count += 1
	_turn_ended()

func process_ui_action(action: Action) -> void:
	if is_turn_active:
		return
	if GameManager.current_state != GameManager.GameState.EXPLORING:
		return
	_process_player_action(action)

func _turn_ended() -> void:
	turn_processed.emit(GameManager.turn_count)
	is_turn_active = false
