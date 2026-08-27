extends Node2D
class_name CharacterManager

const _KEY_NEXT_ID = 1
const _KEY_CHARACTERS = 2

signal character_inspect_requested(character: Character)

var _next_id = 0
var characters: Dictionary[int, Character]
## cell_index -> Vector2i(character_id, behavior_token)
var _stall_claims: Dictionary[int, Vector2i] = {}

func clear() -> void:
	for child in get_children():
		if child is InstancePlaceholder:
			continue
		remove_child(child)
		child.free()
	_next_id = 0
	characters.clear()
	_stall_claims.clear()

func get_character(character_id: int) -> Character:
	return characters.get(character_id)

func create_character() -> Character:
	var character = _instantiate_character()
	_next_id += 1
	character.id = _next_id
	characters[character.id] = character
	return character

func try_claim_stall(cell_index: int, character_id: int, behavior_token: int) -> bool:
	if cell_index < 0 or cell_index >= Game.MAP_CELL_COUNT:
		return false
	var current_claim: Vector2i = _stall_claims.get(cell_index, Vector2i.ZERO)
	if _is_stall_claim_live(current_claim) and current_claim.x != character_id:
		return false
	_stall_claims[cell_index] = Vector2i(character_id, behavior_token)
	return true

func is_stall_claimed_by_other(cell_index: int, character_id: int) -> bool:
	var current_claim: Vector2i = _stall_claims.get(cell_index, Vector2i.ZERO)
	if not _is_stall_claim_live(current_claim):
		return false
	return current_claim.x != character_id

func get_live_stall_cell_index_for(character_id: int, behavior_token: int) -> int:
	for cell_index in _stall_claims:
		var claim: Vector2i = _stall_claims[cell_index]
		if claim.x != character_id or claim.y != behavior_token:
			continue
		if _is_stall_claim_live(claim):
			return cell_index
	return -1

func get_live_stall_cell_indices() -> Array[int]:
	var result: Array[int] = []
	for cell_index in _stall_claims:
		if _is_stall_claim_live(_stall_claims[cell_index]):
			result.append(cell_index)
	result.sort()
	return result

func _is_stall_claim_live(claim: Vector2i) -> bool:
	if claim.x <= 0:
		return false
	var character := get_character(claim.x)
	if character == null or not is_instance_valid(character):
		return false
	return character.ai_behavior_token == claim.y

func _instantiate_character() -> Character:
	var character := %CharacterPlaceHolder.create_instance() as Character
	character.inspect_requested.connect(
			character_inspect_requested.emit.bind(character)
	)
	return character

func serialize() -> Dictionary:
	var list: Array[Dictionary]
	for chr in characters.values():
		var c := chr as Character
		list.append(c.serialize())
	return {
		_KEY_NEXT_ID: _next_id,
		_KEY_CHARACTERS: list,
	}

func deserialize(data: Dictionary) -> void:
	_next_id = data.get(_KEY_NEXT_ID, 0)
	for d in data.get(_KEY_CHARACTERS, []):
		var chr = _instantiate_character()
		chr.deserialize(d)
		characters[chr.id] = chr
