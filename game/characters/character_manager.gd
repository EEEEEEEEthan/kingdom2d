extends Node2D
class_name CharacterManager

func clear() -> void:
	for child in get_children():
		child.queue_free()


func add_character(character: Character) -> void:
	add_child(character)
