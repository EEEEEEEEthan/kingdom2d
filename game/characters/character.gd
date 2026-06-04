extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2

var id: int

func deserialize(data: Dictionary) -> void:
	id = data[_KEY_ID]
	position = Vector2(data[_KEY_POSITION], 0)

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x
	}
