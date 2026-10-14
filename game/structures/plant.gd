@tool
extends Structure
class_name Plant

const _KEY_GROWTH = 1

@export_range(0, 1) var growth: float:
	set(value):
		growth = value
		if not is_node_ready(): await ready
		_on_growth_changed()

func _serialize() -> Dictionary:
	return {
		_KEY_GROWTH: growth
	}

func _deserialize(_data: Dictionary) -> void:
	growth = float(_data.get(_KEY_GROWTH, 0.0))

func _on_growth_changed() -> void:
	pass
