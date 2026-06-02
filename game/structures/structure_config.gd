extends RefCounted
class_name StructureConfig

const ID_OAK := 1

static var oak: StructureConfig:
	get:
		if not oak:
			oak = StructureConfig.new()
			oak.id = ID_OAK
			oak.name = &"橡树"
			oak._scene = preload("res://game/structures/oak.tscn")
		return oak
			
static var configs_by_id: Dictionary[int,StructureConfig] = {
	oak.id: oak
}

var id: int
var name: StringName
var _scene: PackedScene

func instantiate() -> Node2D:
	var structure: Node2D = _scene.instantiate()
	structure.config = self
	return structure
