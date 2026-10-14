extends RefCounted
class_name DwellingGrade

## 住房在 0 级放下、免费升到 1 级之后的生活等级。
## 1→2：屋里有居民，且浆果够吃一天（Food.PER_DAY）。点按钮后仍由建筑工修成木架茅屋。
## 2→3：上述食物还在，且仓库可取出原木达到 LOG_NEED；点升级时立刻扣掉这户自己的那份。
## 已是原木宅的，不再靠仓库数字维持；食物或居民掉了才降级。没有居民不能维持 2 级以上。

const LEVEL_HOVEL := 1
const LEVEL_COTTAGE := 2
const LEVEL_TIMBER := 3
const LOG_NEED := 10


static func resident_count(home: Structure) -> int:
	var game := Game.find(home)
	if game == null:
		return 0
	var count := 0
	for character in game.character_manager.characters.values():
		if character.home_cell_index == home.cell_index:
			count += 1
	return count


static func withdrawable_logs(home: Structure) -> int:
	var game := Game.find(home)
	if game == null:
		return 0
	var total := 0
	for node in game.structure_manager.structures_of_type(StructureConfig.TypeId.WAREHOUSE):
		var warehouse := node as Warehouse
		if warehouse == null or not warehouse.accepts_withdraw(ItemConfig.TypeId.LOG):
			continue
		total += warehouse.container.count_of(ItemConfig.TypeId.LOG)
	return total


## 从允许取出的仓库扣掉升原木宅所需的原木。不够则不动库存并返回 false。
static func consume_upgrade_logs(home: Structure) -> bool:
	var game := Game.find(home)
	if game == null or withdrawable_logs(home) < LOG_NEED:
		return false
	var remaining := LOG_NEED
	var warehouses: Array[Warehouse] = []
	for node in game.structure_manager.structures_of_type(StructureConfig.TypeId.WAREHOUSE):
		var warehouse := node as Warehouse
		if warehouse == null or not warehouse.accepts_withdraw(ItemConfig.TypeId.LOG):
			continue
		if warehouse.container.count_of(ItemConfig.TypeId.LOG) <= 0:
			continue
		warehouses.append(warehouse)
	warehouses.sort_custom(func(a: Warehouse, b: Warehouse) -> bool:
		var da := absi(a.cell_index - home.cell_index)
		var db := absi(b.cell_index - home.cell_index)
		if da != db:
			return da < db
		return a.id < b.id
	)
	for warehouse in warehouses:
		remaining -= warehouse.container.take(ItemConfig.TypeId.LOG, remaining)
		if remaining <= 0:
			return true
	return false


static func sustainable_level(home: Structure) -> int:
	if resident_count(home) < 1 or Food.stored(home) < Food.PER_DAY:
		return LEVEL_HOVEL
	# 升原木宅时已扣掉原木，维持不再盯仓库瞬时数字。
	if home.level >= LEVEL_TIMBER:
		return LEVEL_TIMBER
	if withdrawable_logs(home) < LOG_NEED:
		return LEVEL_COTTAGE
	return LEVEL_TIMBER


static func can_raise(home: Structure, target: int) -> bool:
	if home == null or not home.is_built() or home.is_under_construction():
		return false
	if target != home.level + 1 or sustainable_level(home) < target:
		return false
	if target == LEVEL_COTTAGE:
		if home.config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
			return false
		if bool(home.get("upgrade_ordered")):
			return false
	return true
