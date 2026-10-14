extends RefCounted
class_name Food

## 浆果是食物。住房存 10，每天吃 5。从有货的仓库领取。

const PER_DAY := 5
const HOME_CAPACITY := 10
const ITEM_ID := ItemConfig.TypeId.BERRY


static func is_dwelling(structure: Structure) -> bool:
	if structure == null or not structure.is_built():
		return false
	var type_id := structure.config.id
	return type_id == StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL or type_id == StructureConfig.TypeId.TIMBER_FRAME_COTTAGE


static func home_of(character: Character) -> Structure:
	var game := Game.find(character)
	if game == null:
		return null
	var structure: Structure = game.structure_manager.index_to_structures[character.resolved_home_cell_index()]
	if not is_dwelling(structure):
		return null
	return structure


static func stored(home: Structure) -> int:
	return home.container.count_of(ITEM_ID)


static func space(home: Structure) -> int:
	return maxi(0, HOME_CAPACITY - stored(home))


static func deposit(home: Structure, source: ItemContainer) -> void:
	var moving := mini(source.count_of(ITEM_ID), space(home))
	if moving <= 0:
		return
	source.take(ITEM_ID, moving)
	home.container.add(ITEM_ID, moving)


## 先尽量放进住房，放不下的退回最近仓库。
static func settle_carried(character: Character) -> void:
	var home := home_of(character)
	if home:
		deposit(home, character.carried_items)
	var left := character.carried_items.count_of(ITEM_ID)
	if left <= 0:
		return
	var warehouse := nearest_warehouse(character)
	if warehouse == null:
		return
	character.carried_items.take(ITEM_ID, left)
	warehouse.restore_berries(left)


static func eat(home: Structure) -> void:
	home.container.take(ITEM_ID, PER_DAY)


static func nearest_stocked_warehouse(character: Character) -> Warehouse:
	var game := Game.find(character)
	if game == null:
		return null
	var origin := roundi((character.position.x - Game.HALF_TILE_SIZE) / float(Game.TILE_SIZE))
	return Warehouse.nearest(
		game.structure_manager,
		origin,
		ITEM_ID,
		false,
		true,
		true,
	)


static func nearest_warehouse(character: Character) -> Warehouse:
	var game := Game.find(character)
	if game == null:
		return null
	var origin := roundi((character.position.x - Game.HALF_TILE_SIZE) / float(Game.TILE_SIZE))
	return Warehouse.nearest(
		game.structure_manager,
		origin,
		ITEM_ID,
		false,
		false,
		false,
		false,
	)
