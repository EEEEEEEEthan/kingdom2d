extends Node2D
class_name Structure

const TYPE_OAK = 1

const _KEY_ID = 1
const _KEY_DATA = 2

static func deserialize(data: Dictionary) -> Structure:
	var type_id := data[_KEY_ID] as int
	var scene: PackedScene
	match type_id:
		TYPE_OAK:
			scene = ResourceLoader.load("res://game/structures/oak.tscn")
	if scene:
		var obj = scene.instantiate()
		obj._on_deserialize(data[_KEY_DATA])
	return null

func get_id() -> int:
	printerr("等待子类override")
	return 0

func _deserialize(_data: Dictionary) -> void:
	pass

func serialize() -> Dictionary:
	return{
		_KEY_ID: get_id(),
		_KEY_DATA: _serialize(),
	}

func _serialize() -> Dictionary:
	return {}
