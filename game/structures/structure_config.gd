extends RefCounted
class_name StructureConfig

enum TypeId {
	NONE = 0,
	OAK = 1,
	SUNKEN_FLOOR_THATCH_HOVEL = 2,
}

static var oak: StructureConfig:
	get:
		if not oak:
			oak = StructureConfig.new()
			oak.id = TypeId.OAK
			oak.name = &"橡树"
			oak._scene_path = &"res://game/structures/oak.tscn"
		return oak

static var sunken_floor_thatch_hovel: StructureConfig:
	get:
		if not sunken_floor_thatch_hovel:
			sunken_floor_thatch_hovel = StructureConfig.new()
			sunken_floor_thatch_hovel.id = TypeId.SUNKEN_FLOOR_THATCH_HOVEL
			sunken_floor_thatch_hovel.name = &"半穴茅舍"
			sunken_floor_thatch_hovel._scene_path = &"res://game/structures/sunken_floor_thatch_hovel.tscn"
		return sunken_floor_thatch_hovel

static var configs_by_id: Dictionary[TypeId, StructureConfig] = {
	oak.id: oak,
	sunken_floor_thatch_hovel.id: sunken_floor_thatch_hovel,
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
