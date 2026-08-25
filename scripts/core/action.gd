class_name Action
extends RefCounted

var actor_index: int

func _init(p_actor_index: int = -1) -> void:
	actor_index = p_actor_index

func execute(_world: Node) -> bool:
	return false

func get_action_name() -> String:
	return "action"
