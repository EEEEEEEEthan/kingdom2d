extends Node
class_name StructureManager

const _KEY_NEXT_ID = 1
const _KEY_STRUCTURES = 2
const _KEY_OCCUPANTS = 3

var _next_id = 0
var index_to_structures: Array[Structure] = []
var structures: Dictionary[int, Structure] = {}
var _structures_by_type: Dictionary[int, Array] = {}
var _occupant_by_structure_id: Dictionary[int, int] = {}


func clear() -> void:
	for structure in index_to_structures:
		if structure:
			structure.queue_free()
	_next_id = 0
	index_to_structures.clear()
	index_to_structures.resize(Game.MAP_CELL_COUNT)
	structures.clear()
	_structures_by_type.clear()
	_occupant_by_structure_id.clear()


func serialize() -> Dictionary:
	var structure_data: Array[Dictionary] = []
	for structure in structures.values():
		structure_data.append((structure as Structure).serialize())
	return {
		_KEY_NEXT_ID: _next_id,
		_KEY_STRUCTURES: structure_data,
		_KEY_OCCUPANTS: _occupant_by_structure_id,
	}


func deserialize(data: Dictionary, save_version := 0) -> void:
	_next_id = data[_KEY_NEXT_ID]
	var structure_data: Array = data[_KEY_STRUCTURES]
	for item in structure_data:
		var structure = Structure.deserialize(item, self, save_version)
		if structure == null:
			continue
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
	return structures.get(structure_id)


func structures_of_type(type_id: int) -> Array:
	return _structures_by_type.get(type_id, [])


enum AddError {
	OK,
	CELL_OCCUPIED,
	CELL_OUT_OF_RANGE,
}


## dry_run 为 true 时只返回错误码，不挂节点、不分配 id。
func add_structure(structure: Structure, cell_index: int, dry_run := false) -> AddError:
	var error := _add_error(cell_index)
	if dry_run or error != AddError.OK:
		return error
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
	return AddError.OK


func _add_error(cell_index: int) -> AddError:
	if cell_index < 0 or cell_index >= index_to_structures.size():
		return AddError.CELL_OUT_OF_RANGE
	if index_to_structures[cell_index]:
		return AddError.CELL_OCCUPIED
	return AddError.OK


func _register_structure(structure: Structure) -> void:
	if index_to_structures[structure.cell_index]:
		printerr("建筑重叠!");
		return
	var cell_index := structure.cell_index
	index_to_structures[cell_index] = structure
	structures[structure.id] = structure
	var type_id := int(structure.config.id)
	if not _structures_by_type.has(type_id):
		_structures_by_type[type_id] = []
	(_structures_by_type[type_id] as Array).append(structure)
	await structure.tree_exiting
	if index_to_structures[cell_index] == structure:
		index_to_structures[cell_index] = null
	if structures.get(structure.id) == structure:
		structures.erase(structure.id)
	var bucket: Array = _structures_by_type.get(type_id, [])
	bucket.erase(structure)
	var game := Game.find(self)
	if game:
		game.employment.release_structure(structure.id)
