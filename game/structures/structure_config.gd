extends RefCounted
class_name StructureConfig

enum TypeId {
	NONE = 0,
	OAK = 1,
	SUNKEN_FLOOR_THATCH_HOVEL = 2,
	SOVEREIGN_BANNER = 3,
	BUSH = 4,
	REFUGEE_HUT = 5,
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

static var sovereign_banner: StructureConfig:
	get:
		if not sovereign_banner:
			sovereign_banner = StructureConfig.new()
			sovereign_banner.id = TypeId.SOVEREIGN_BANNER
			sovereign_banner.name = &"王权旌旗"
			sovereign_banner._scene_path = &"res://game/structures/sovereign_banner.tscn"
		return sovereign_banner

static var refugee_hut: StructureConfig:
	get:
		if not refugee_hut:
			refugee_hut = StructureConfig.new()
			refugee_hut.id = TypeId.REFUGEE_HUT
			refugee_hut.name = &"难民棚"
			refugee_hut._scene_path = &"res://game/structures/refugee_hut.tscn"
		return refugee_hut

static var bush: StructureConfig:
	get:
		if not bush:
			bush = StructureConfig.new()
			bush.id = TypeId.BUSH
			bush.name = &"灌木"
			bush._scene_path = &"res://game/structures/bush.tscn"
		return bush

static var configs_by_id: Dictionary[TypeId, StructureConfig] = {
	oak.id: oak,
	sunken_floor_thatch_hovel.id: sunken_floor_thatch_hovel,
	sovereign_banner.id: sovereign_banner,
	bush.id: bush,
	refugee_hut.id: refugee_hut,
}

var id: TypeId = TypeId.NONE
var name: StringName
var max_hp = 32
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
