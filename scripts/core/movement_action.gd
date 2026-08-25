class_name MovementAction
extends Action

var direction: Vector2i

func _init(p_actor_index: int, p_direction: Vector2i) -> void:
	super._init(p_actor_index)
	direction = p_direction

func execute(world: Node) -> bool:
	if world.has_method("try_move"):
		return world.try_move(actor_index, direction)
	return false

func get_action_name() -> String:
	return "move"
