extends RefCounted
class_name StructureConfig

enum TypeId {
	NONE = 0,
	OAK = 1,
}

static var oak: StructureConfig:
	get:
		if not oak:
			oak = StructureConfig.new()
			oak.id = TypeId.OAK
			oak.name = &"橡树"
			oak._scene_path = &"res://game/structures/oak.tscn"
		return oak
			
static var configs_by_id: Dictionary[TypeId,StructureConfig] = {
	oak.id: oak
}

var id: TypeId = TypeId.NONE
var name: StringName
var _scene_path: StringName
var _scene: PackedScene:
	get:
		if not _scene:
			_scene = ResourceLoader.load(_scene_path)
		return _scene

func instantiate() -> Node2D:
	var structure: Node2D = _scene.instantiate()
	structure.config = self
	return structure
