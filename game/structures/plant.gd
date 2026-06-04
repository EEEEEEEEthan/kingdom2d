extends Structure
class_name Plant

const _KEY_GROWTH = 1

var growth: float

func _serialize() -> Dictionary:
	return {
		_KEY_GROWTH: growth
	}

func _deserialize(_data: Dictionary) -> void:
	growth = _data[_KEY_GROWTH]
