extends Node
class_name StructureManager

const _KEY_NEXT_ID = 1
const _KEY_STRUCTURES = 2

var _next_id = 0
var index_to_structures: Array[Structure] = []


func clear() -> void:
	for structure in index_to_structures:
		if structure:
			structure.queue_free()
	_next_id = 0
	index_to_structures.clear()
	index_to_structures.resize(Game.MAP_CELL_COUNT)


func serialize() -> Dictionary:
	var structures: Array[Dictionary] = []
	var result = {
		_KEY_NEXT_ID: _next_id,
		_KEY_STRUCTURES: structures,
	}
	for structure_slot in index_to_structures:
		if not structure_slot:
			continue
		var structure = structure_slot as Structure
		structures.append(structure.serialize())
	return result


func deserialize(data: Dictionary) -> void:
	_next_id = data[_KEY_NEXT_ID]
	var structures: Array = data[_KEY_STRUCTURES]
	for item in structures:
		var structure = Structure.deserialize(item, self)
		_register_structure(structure)


func get_structure_by_id(structure_id: int) -> Structure:
	for structure in index_to_structures:
		if structure and structure.id == structure_id:
			return structure
	return null


func add_structure(structure: Structure, cell_index: int) -> void:
	_next_id += 1
	structure.id = _next_id
	structure.cell_index = cell_index
	if structure.get_parent() != self:
		add_child(structure)
	_register_structure(structure)
	if structure is GathererHut:
		var game := _game()
		if game:
			game.rebalance_workplaces()


func _game() -> Game:
	var node: Node = self
	while node:
		if node is Game:
			return node
		node = node.get_parent()
	return null


func _register_structure(structure: Structure) -> void:
	if index_to_structures[structure.cell_index]:
		printerr("建筑重叠!");
		return
	index_to_structures[structure.cell_index] = structure
	await structure.tree_exiting
	index_to_structures[structure.cell_index] = null
