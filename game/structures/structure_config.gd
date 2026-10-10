extends RefCounted
class_name StructureConfig

enum TypeId {
	NONE = 0,
	OAK = 1,
	SUNKEN_FLOOR_THATCH_HOVEL = 2,
	SOVEREIGN_BANNER = 3,
	BUSH = 4,
	TENT = 5,
	WOOD_CABIN = 6,
	LUMBER_CAMP = 7,
	BUILDERS_GUILD = 8,
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

static var bush: StructureConfig:
	get:
		if not bush:
			bush = StructureConfig.new()
			bush.id = TypeId.BUSH
			bush.name = &"灌木"
			bush._scene_path = &"res://game/structures/bush.tscn"
		return bush

static var tent: StructureConfig:
	get:
		if not tent:
			tent = StructureConfig.new()
			tent.id = TypeId.TENT
			tent.name = &"帐篷"
			tent._scene_path = &"res://game/structures/tent.tscn"
		return tent

static var wood_cabin: StructureConfig:
	get:
		if not wood_cabin:
			wood_cabin = StructureConfig.new()
			wood_cabin.id = TypeId.WOOD_CABIN
			wood_cabin.name = &"小木屋"
			wood_cabin.show_in_build_menu = false
			wood_cabin._scene_path = &"res://game/structures/wood_cabin.tscn"
		return wood_cabin

static var lumber_camp: StructureConfig:
	get:
		if not lumber_camp:
			lumber_camp = StructureConfig.new()
			lumber_camp.id = TypeId.LUMBER_CAMP
			lumber_camp.name = &"伐木营地"
			lumber_camp._scene_path = &"res://game/structures/lumber_camp.tscn"
		return lumber_camp

static var builders_guild: StructureConfig:
	get:
		if not builders_guild:
			builders_guild = StructureConfig.new()
			builders_guild.id = TypeId.BUILDERS_GUILD
			builders_guild.name = &"建筑工工会"
			builders_guild._scene_path = &"res://game/structures/builders_guild.tscn"
		return builders_guild

static var configs_by_id: Dictionary[TypeId, StructureConfig] = {
	oak.id: oak,
	sunken_floor_thatch_hovel.id: sunken_floor_thatch_hovel,
	sovereign_banner.id: sovereign_banner,
	bush.id: bush,
	tent.id: tent,
	wood_cabin.id: wood_cabin,
	lumber_camp.id: lumber_camp,
	builders_guild.id: builders_guild,
}

var id: TypeId = TypeId.NONE
var name: StringName
var show_in_build_menu := true
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
