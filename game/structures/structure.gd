extends Node2D
class_name Structure

const TYPE_OAK = 1

const _KEY_TYPE_ID = 1
const _KEY_INSTANCE_ID = 2
const _KEY_DATA = 3
const _KEY_CELL_INDEX = 4

static func deserialize(data: Dictionary, parent: Node) -> Structure:
	var type_id := data[_KEY_TYPE_ID] as int
	var scene: PackedScene
	match type_id:
		TYPE_OAK:
			scene = ResourceLoader.load("res://game/structures/oak.tscn")
	if scene:
		var obj = scene.instantiate() as Structure
		parent.add_child(obj)
		obj.id = data[_KEY_INSTANCE_ID]
		obj.cell_index = data[_KEY_CELL_INDEX]
		obj._on_deserialize(data[_KEY_DATA])
	return null

var id: int
var cell_index: int:
	get:
		return cell_index
	set(value):
		cell_index = value
		if not is_node_ready(): await ready
		position = Vector2(value * Game.TILE_SIZE, 0)

func get_type_id() -> int:
	printerr("等待子类override")
	return 0

func _deserialize(_data: Dictionary) -> void:
	pass

func serialize() -> Dictionary:
	return{
		_KEY_TYPE_ID: get_type_id(),
		_KEY_INSTANCE_ID: id,
		_KEY_DATA: _serialize(),
		_KEY_CELL_INDEX: cell_index,
	}

func _serialize() -> Dictionary:
	return {}
