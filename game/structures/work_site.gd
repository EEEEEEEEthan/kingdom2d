extends Structure
class_name WorkSite

## 仓库、住房、伐木营地、建筑工工会。库存挂在建筑上，不是隐形全局仓。

enum Kind { NONE, WAREHOUSE, HOME, LUMBER, GUILD }

const UPGRADE_NONE := 0
const UPGRADE_CABIN := 1
const UPGRADE_CAPACITY := 2
const CABIN_LOG_COST := 3
const CAPACITY_LOG_COST := 4
const CAPACITY_BONUS := 12
const WAREHOUSE_CAPACITY := 24
const CAMP_CAPACITY := 8
const GUILD_CAPACITY := 8

const _KEY_STOCK = 1
const _KEY_RESIDENT = 2
const _KEY_REMAINING = 3
const _KEY_UPGRADE = 4

var kind: Kind = Kind.NONE
var stock: Stockpile
var resident_id: int = 0
var material_remaining: int = 0
var upgrade_goal: int = UPGRADE_NONE


func _ready() -> void:
	_apply_role_defaults()


func _apply_role_defaults() -> void:
	if config == null:
		return
	match config.id:
		StructureConfig.TypeId.SOVEREIGN_BANNER:
			kind = Kind.WAREHOUSE
			if stock == null:
				stock = Stockpile.new()
				stock.capacity = WAREHOUSE_CAPACITY
				stock.set_policy(LogisticsUnit.ITEM_WOOD, Stockpile.Policy.ACCEPT)
		StructureConfig.TypeId.LUMBER_CAMP:
			kind = Kind.LUMBER
			if stock == null:
				stock = Stockpile.new()
				stock.capacity = CAMP_CAPACITY
		StructureConfig.TypeId.BUILDERS_GUILD:
			kind = Kind.GUILD
			if stock == null:
				stock = Stockpile.new()
				stock.capacity = GUILD_CAPACITY
		StructureConfig.TypeId.TENT, StructureConfig.TypeId.WOOD_CABIN:
			kind = Kind.HOME
		_:
			kind = Kind.NONE


func on_player_placed(game: Game) -> void:
	if kind != Kind.HOME or resident_id != 0:
		return
	if config.id != StructureConfig.TypeId.TENT:
		return
	var resident := game.character_manager.create_character()
	resident.position.x = position.x
	resident.home_structure_id = id
	resident_id = resident.id


func order_cabin() -> void:
	if config.id != StructureConfig.TypeId.TENT or upgrade_goal != UPGRADE_NONE:
		return
	upgrade_goal = UPGRADE_CABIN
	material_remaining = CABIN_LOG_COST


func order_capacity() -> void:
	if kind != Kind.WAREHOUSE or upgrade_goal != UPGRADE_NONE:
		return
	upgrade_goal = UPGRADE_CAPACITY
	material_remaining = CAPACITY_LOG_COST


func receive_one() -> void:
	if material_remaining <= 0:
		return
	material_remaining -= 1
	if material_remaining > 0:
		return
	if upgrade_goal == UPGRADE_CAPACITY and stock:
		stock.capacity += CAPACITY_BONUS
	elif upgrade_goal == UPGRADE_CABIN:
		config = StructureConfig.wood_cabin
		kind = Kind.HOME
		if has_node(^"%Sprite2D"):
			%Sprite2D.texture = load("res://game/structures/art/wood_cabin.png")
	upgrade_goal = UPGRADE_NONE
	material_remaining = 0


func _serialize() -> Dictionary:
	var data := {
		_KEY_RESIDENT: resident_id,
		_KEY_REMAINING: material_remaining,
		_KEY_UPGRADE: upgrade_goal,
	}
	if stock:
		data[_KEY_STOCK] = stock.serialize()
	return data


func _deserialize(data: Dictionary) -> void:
	resident_id = int(data.get(_KEY_RESIDENT, 0))
	material_remaining = int(data.get(_KEY_REMAINING, 0))
	upgrade_goal = int(data.get(_KEY_UPGRADE, UPGRADE_NONE))
	if data.has(_KEY_STOCK):
		if stock == null:
			stock = Stockpile.new()
		stock.deserialize(data[_KEY_STOCK])


static func plan_job(site: WorkSite, sites: Array) -> LogisticsUnit:
	if site == null:
		return null
	if site.kind == Kind.LUMBER:
		return LogisticsUnit.lumber(site.id)
	if site.kind != Kind.GUILD:
		return null
	var job = _nearest_open_job(site, sites)
	if job == null:
		return null
	if site.stock and site.stock.amount(LogisticsUnit.ITEM_WOOD) >= 1:
		return LogisticsUnit.build(site.id, job.id)
	var source = LogisticsUnit.nearest_fetch_source(site.cell_index, sites)
	if source:
		return LogisticsUnit.fetch(site.id, source.id)
	return null


static func _nearest_open_job(guild: WorkSite, sites: Array):
	var best = null
	var best_distance := 1 << 30
	for site in sites:
		if site == null or int(site.material_remaining) <= 0:
			continue
		var distance := absi(int(site.cell_index) - guild.cell_index)
		if distance < best_distance:
			best = site
			best_distance = distance
	return best
