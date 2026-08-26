extends Node
class_name StructureManager

const _KEY_NEXT_ID = 1
const _KEY_STRUCTURES = 2

var _next_id = 0
var index_to_structures: Array[Structure] = []
var _harvest_claims: Dictionary[int, int] = {}


func clear() -> void:
	for structure in index_to_structures:
		if structure:
			structure.queue_free()
	_next_id = 0
	_harvest_claims.clear()
	index_to_structures.clear()
	index_to_structures.resize(Game.MAP_CELL_COUNT)


func try_claim_harvest(structure_id: int, character_id: int) -> bool:
	var current_claimer_id: int = _harvest_claims.get(structure_id, 0)
	if current_claimer_id == character_id:
		return true
	if current_claimer_id != 0:
		return false
	_harvest_claims[structure_id] = character_id
	return true


func release_harvest_claim(structure_id: int, character_id: int) -> void:
	if _harvest_claims.get(structure_id, 0) != character_id:
		return
	_harvest_claims.erase(structure_id)


func is_harvest_claimed_by_other(structure_id: int, character_id: int) -> bool:
	var current_claimer_id: int = _harvest_claims.get(structure_id, 0)
	return current_claimer_id != 0 and current_claimer_id != character_id


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


func _register_structure(structure: Structure) -> void:
	if index_to_structures[structure.cell_index]:
		printerr("建筑重叠!");
		return
	index_to_structures[structure.cell_index] = structure
	var structure_id := structure.id
	await structure.tree_exiting
	_harvest_claims.erase(structure_id)
	index_to_structures[structure.cell_index] = null
