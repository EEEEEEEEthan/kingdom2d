extends Node2D
class_name CharacterManager

const _KEY_NEXT_ID = 1
const KEY_CHARACTERS = 2

var _next_id = 0
var characters: Dictionary[int, Character]

func clear() -> void:
	for child in get_children():
		if child is InstancePlaceholder:
			continue
		remove_child(child)
		child.free()
	_next_id = 0
	characters.clear()

func create_character() -> Character:
	var character = _instantiate_character()
	_next_id += 1
	character.id = _next_id
	characters[character.id] = character
	return character

func _instantiate_character() -> Character:
	return %CharacterPlaceHolder.create_instance() as Character

func serialize() -> Dictionary:
	var list: Array[Dictionary]
	for chr in characters.values():
		var c := chr as Character
		list.append(c.serialize())
	return {
		_KEY_NEXT_ID: _next_id,
		KEY_CHARACTERS: list,
	}

func deserialize(data: Dictionary) -> void:
	var saw_next := data.has(_KEY_NEXT_ID)
	_next_id = int(data.get(_KEY_NEXT_ID, 0))
	var listed = data.get(KEY_CHARACTERS, [])
	if not listed is Array:
		return
	for d in listed:
		if not d is Dictionary:
			continue
		var chr = _instantiate_character()
		if not chr.deserialize(d):
			chr.free()
			continue
		if characters.has(chr.id):
			chr.free()
			continue
		characters[chr.id] = chr
		if not saw_next:
			_next_id = maxi(_next_id, chr.id)
