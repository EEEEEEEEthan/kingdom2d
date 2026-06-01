extends Node
class_name StructureManager

const _KEY_NEXT_ID = 1
const _KEY_STRUCTURES = 2

var _next_id = 0
var id_to_structures: Dictionary[int, Structure]
var index_to_structures: Array[Structure]

func serialize() -> Dictionary:
	var structures = []
	var result = {
		_KEY_NEXT_ID = _next_id,
		_KEY_STRUCTURES = structures
	}
	_next_id = result
	for s in id_to_structures.values():
		var structure = s as Structure
		structures.append(structure.serialize())
	return result

func deserialize(data: Dictionary) -> void:
	_next_id = data[_KEY_NEXT_ID]
	var array = data[_KEY_STRUCTURES]
	for item in array:
		var structure = Structure.deserialize(item, self)
		_register_structure(structure)

func add_structure(structure: Structure, cell_index: int) -> void:
	structure.position = Vector2(Game.get_position_by_cell_index(cell_index), 0)
	_next_id += 1
	structure.id = _next_id
	_register_structure(structure)

func _register_structure(structure: Structure) -> void:
	if index_to_structures[structure.cell_index]:
		printerr("建筑重叠!");
		return
	id_to_structures[structure.id] = structure
	index_to_structures[structure.cell_index] = structure
	await structure.tree_exiting
	id_to_structures[structure.id] = null
	index_to_structures[structure.cell_index] = null
