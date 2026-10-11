extends Node
class_name StructureManager

const _KEY_NEXT_ID = 1
const _KEY_STRUCTURES = 2

var _next_id = 0
var index_to_structures: Array[Structure] = []
var structures: Dictionary[int, Structure] = {}


func clear() -> void:
	for structure in index_to_structures:
		if structure:
			structure.queue_free()
	_next_id = 0
	index_to_structures.clear()
	index_to_structures.resize(Game.MAP_CELL_COUNT)
	structures.clear()


func serialize() -> Dictionary:
	var structure_data: Array[Dictionary] = []
	for structure in structures.values():
		structure_data.append((structure as Structure).serialize())
	return {
		_KEY_NEXT_ID: _next_id,
		_KEY_STRUCTURES: structure_data,
	}


func deserialize(data: Dictionary) -> void:
	_next_id = data[_KEY_NEXT_ID]
	var structure_data: Array = data[_KEY_STRUCTURES]
	for item in structure_data:
		var structure = Structure.deserialize(item, self)
		_register_structure(structure)


func get_structure_by_id(structure_id: int) -> Structure:
	return structures.get(structure_id)


func add_structure(structure: Structure, cell_index: int) -> void:
	_next_id += 1
	structure.id = _next_id
	structure.cell_index = cell_index
	if structure.get_parent() != self:
		add_child(structure)
	_register_structure(structure)
	if structure is GathererHut:
		var game := Game.find(self)
		if game:
			game.rebalance_workplaces()


func _register_structure(structure: Structure) -> void:
	if index_to_structures[structure.cell_index]:
		printerr("建筑重叠!");
		return
	var cell_index := structure.cell_index
	index_to_structures[cell_index] = structure
	structures[structure.id] = structure
	await structure.tree_exiting
	if index_to_structures[cell_index] == structure:
		index_to_structures[cell_index] = null
	if structures.get(structure.id) == structure:
		structures.erase(structure.id)
