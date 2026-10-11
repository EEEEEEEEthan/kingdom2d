extends Node
class_name StructureManager

const _KEY_NEXT_ID = 1
const _KEY_STRUCTURES = 2
const _KEY_OCCUPANTS = 3

var _next_id = 0
var index_to_structures: Array[Structure] = []
var _occupant_by_structure_id: Dictionary[int, int] = {}


func clear() -> void:
	for structure in index_to_structures:
		if structure:
			structure.queue_free()
	_next_id = 0
	index_to_structures.clear()
	index_to_structures.resize(Game.MAP_CELL_COUNT)
	_occupant_by_structure_id.clear()


func serialize() -> Dictionary:
	var structures: Array[Dictionary] = []
	var result = {
		_KEY_NEXT_ID: _next_id,
		_KEY_STRUCTURES: structures,
		_KEY_OCCUPANTS: _occupant_by_structure_id,
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
	_occupant_by_structure_id.clear()
	var occupants: Dictionary = data.get(_KEY_OCCUPANTS, {})
	for structure_id in occupants:
		_occupant_by_structure_id[int(structure_id)] = int(occupants[structure_id])


## by_character_id 传 0 表示解除占用。
func mark_occupied(structure_id: int, by_character_id: int) -> void:
	if by_character_id == 0:
		_occupant_by_structure_id.erase(structure_id)
	else:
		_occupant_by_structure_id[structure_id] = by_character_id


func occupant_of(structure_id: int) -> int:
	return _occupant_by_structure_id.get(structure_id, 0)


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
	if index_to_structures[structure.cell_index] == structure:
		index_to_structures[structure.cell_index] = null
