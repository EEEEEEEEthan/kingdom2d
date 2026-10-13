extends RefCounted
class_name StructureConfig

enum TypeId {
	NONE = 0,
	OAK = 1,
	SUNKEN_FLOOR_THATCH_HOVEL = 2,
	SOVEREIGN_BANNER = 3,
	BUSH = 4,
	GATHERER_HUT = 5,
	WAREHOUSE = 6,
	# 7 是旧档难民棚，见 Structure._LEGACY_REFUGEE_SHELTER。
	LUMBER_CAMP = 8,
	BUILDERS_GUILD = 9,
	TIMBER_FRAME_COTTAGE = 10,
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
			sunken_floor_thatch_hovel.uses_construction = true
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

static var gatherer_hut: StructureConfig:
	get:
		if not gatherer_hut:
			gatherer_hut = StructureConfig.new()
			gatherer_hut.id = TypeId.GATHERER_HUT
			gatherer_hut.name = &"采集者小屋"
			gatherer_hut.uses_construction = true
			gatherer_hut._scene_path = &"res://game/structures/gatherer_hut.tscn"
		return gatherer_hut

static var warehouse: StructureConfig:
	get:
		if not warehouse:
			warehouse = StructureConfig.new()
			warehouse.id = TypeId.WAREHOUSE
			warehouse.name = &"仓库"
			warehouse.uses_construction = true
			warehouse.build_log_cost = 10
			warehouse.build_work_units = 2
			warehouse._scene_path = &"res://game/structures/warehouse.tscn"
		return warehouse

static var lumber_camp: StructureConfig:
	get:
		if not lumber_camp:
			lumber_camp = StructureConfig.new()
			lumber_camp.id = TypeId.LUMBER_CAMP
			lumber_camp.name = &"伐木营地"
			lumber_camp.uses_construction = true
			lumber_camp._scene_path = &"res://game/structures/lumber_camp.tscn"
		return lumber_camp

static var builders_guild: StructureConfig:
	get:
		if not builders_guild:
			builders_guild = StructureConfig.new()
			builders_guild.id = TypeId.BUILDERS_GUILD
			builders_guild.name = &"建筑工会"
			builders_guild.uses_construction = true
			builders_guild._scene_path = &"res://game/structures/builders_guild.tscn"
		return builders_guild

static var timber_frame_cottage: StructureConfig:
	get:
		if not timber_frame_cottage:
			timber_frame_cottage = StructureConfig.new()
			timber_frame_cottage.id = TypeId.TIMBER_FRAME_COTTAGE
			timber_frame_cottage.name = &"木架茅屋"
			timber_frame_cottage.placeable = false
			timber_frame_cottage._scene_path = &"res://game/structures/timber_frame_cottage.tscn"
		return timber_frame_cottage

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
	gatherer_hut.id: gatherer_hut,
	warehouse.id: warehouse,
	lumber_camp.id: lumber_camp,
	builders_guild.id: builders_guild,
	timber_frame_cottage.id: timber_frame_cottage,
}

var id: TypeId = TypeId.NONE
var name: StringName
var placeable := true
## 玩家放置时走 0 级→升级流程；植物等为 false。
var uses_construction := false
## 初始修建所需原木；0 且 build_work_units 为 0 时即时完工。
var build_log_cost := 0
var build_work_units := 0
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
