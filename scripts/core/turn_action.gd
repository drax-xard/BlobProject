class_name TurnAction
extends Action

var turn_direction: int

const LEFT: int = -1
const RIGHT: int = 1

func _init(p_actor_index: int, p_direction: int) -> void:
	super._init(p_actor_index)
	turn_direction = p_direction

func execute(world: Node) -> bool:
	if world.has_method("try_turn"):
		return world.try_turn(actor_index, turn_direction)
	return false

func get_action_name() -> String:
	return "turn"
