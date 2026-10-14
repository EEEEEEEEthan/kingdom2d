extends RefCounted
class_name DwellingGrade

## 住房在 0 级放下、免费升到 1 级之后的生活等级。
## 1→2：屋里有居民，且浆果够吃一天（Food.PER_DAY）。点按钮后仍由建筑工修成木架茅屋。
## 2→3：上述食物还在，且结算里可取出的原木达到 LOG_NEED。
## 更高一级的门槛掉了，就降到仍然满足的最高一级。没有居民不能维持 2 级以上。

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


static func sustainable_level(home: Structure) -> int:
	if resident_count(home) < 1 or Food.stored(home) < Food.PER_DAY:
		return LEVEL_HOVEL
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
