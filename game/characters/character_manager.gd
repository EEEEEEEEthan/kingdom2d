extends Node2D
class_name CharacterManager

const _KEY_NEXT_ID = 1
const _KEY_CHARACTERS = 2

signal character_inspect_requested(character: Character)

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
