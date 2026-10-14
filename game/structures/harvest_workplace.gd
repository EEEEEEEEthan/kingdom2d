extends Structure
class_name HarvestWorkplace

## 采集小屋与伐木营地共用库存上限。存入不截断，放不下的留在容器里。

const HAUL_BATCH := 10


func harvest_item_id() -> int:
	return ItemConfig.TypeId.NONE


func harvest_plant_type_id() -> int:
	return StructureConfig.TypeId.NONE


func harvest_capacity() -> int:
	return 0


func stock_count() -> int:
	return container.count_of(harvest_item_id())


func storage_full() -> bool:
	return stock_count() >= harvest_capacity()


func withdraw_harvest(target: ItemContainer, amount: int) -> int:
	var item_id := harvest_item_id()
	var moved := container.take(item_id, amount)
	if moved > 0:
		target.add(item_id, moved)
	return moved


## 只收本工位的收获物。身上其它物品不动。
func deposit_carried(source: ItemContainer) -> void:
	deposit_harvest(source, source.count_of(harvest_item_id()))


func deposit_harvest(source: ItemContainer, amount: int) -> void:
	var item_id := harvest_item_id()
	var moving := mini(amount, source.count_of(item_id))
	if moving <= 0:
		return
	source.take(item_id, moving)
	container.add(item_id, moving)
