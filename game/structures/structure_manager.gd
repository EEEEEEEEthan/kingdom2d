extends Node
class_name StructureManager

const _KEY_NEXT_ID = 1
const _KEY_STRUCTURES = 2

var _next_id = 0
var index_to_structures: Array[Structure] = []
## structure_id -> Vector2i(character_id, behavior_token)
var _harvest_claims: Dictionary[int, Vector2i] = {}


func clear() -> void:
	for structure in index_to_structures:
		if structure:
			structure.queue_free()
	_next_id = 0
	_harvest_claims.clear()
	index_to_structures.clear()
	index_to_structures.resize(Game.MAP_CELL_COUNT)


func try_claim_harvest(structure_id: int, character_id: int, behavior_token: int) -> bool:
	var current_claim: Vector2i = _harvest_claims.get(structure_id, Vector2i.ZERO)
	if _is_harvest_claim_live(current_claim) and current_claim.x != character_id:
		return false
	_harvest_claims[structure_id] = Vector2i(character_id, behavior_token)
	return true


func is_harvest_claimed_by_other(
		structure_id: int,
		character_id: int,
		behavior_token: int
) -> bool:
	var current_claim: Vector2i = _harvest_claims.get(structure_id, Vector2i.ZERO)
	if not _is_harvest_claim_live(current_claim):
		return false
	return current_claim.x != character_id or current_claim.y != behavior_token


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


func _is_harvest_claim_live(claim: Vector2i) -> bool:
	if claim.x <= 0:
		return false
	var character := _resolve_game().character_manager.get_character(claim.x)
	if character == null or not is_instance_valid(character):
		return false
	return character.ai_behavior_token == claim.y


func _resolve_game() -> Game:
	var node: Node = self
	while node:
		if node is Game:
			return node
		node = node.get_parent()
	assert(false, "StructureManager must live under Game")
	return null
