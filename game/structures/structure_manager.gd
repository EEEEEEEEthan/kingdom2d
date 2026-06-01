extends Node
class_name StructureManager

func serialize() -> Dictionary:
	get:
		

func add_structure(_structure: Structure, index: int) -> void:
	_structure.position = Vector2(Game.get_position_by_cell_index(index), 0)
