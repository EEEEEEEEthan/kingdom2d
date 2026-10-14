extends Structure
class_name HarvestWorkplace

## 采集小屋与伐木营地共用库存上限与存入截断。

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


func deposit_carried(source: ItemContainer) -> void:
	source.transfer_all_to(container)
	var item_id := harvest_item_id()
	var capacity := harvest_capacity()
	if container.count_of(item_id) > capacity:
		container.set_count(item_id, capacity)
