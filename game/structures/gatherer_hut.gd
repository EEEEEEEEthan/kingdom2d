extends HarvestWorkplace
class_name GathererHut

const SLOT_COUNT := 2
const BERRY_CAPACITY := 10
const KEY_WORKER_IDS := 1
const _KEY_PRIORITY := 2
const _KEY_PRIORITY_ORDER := 3

var priority := WorkplacePriority.Priority.NORMAL


func harvest_item_id() -> int:
	return ItemConfig.TypeId.BERRY


func harvest_plant_type_id() -> int:
	return StructureConfig.TypeId.BUSH


func harvest_capacity() -> int:
	return BERRY_CAPACITY


func _serialize() -> Dictionary:
	return {
		_KEY_PRIORITY: priority,
		_KEY_PRIORITY_ORDER: 1,
	}


func _deserialize(data: Dictionary) -> void:
	var stored := int(data.get(_KEY_PRIORITY, WorkplacePriority.Priority.HIGH))
	if int(data.get(_KEY_PRIORITY_ORDER, 0)) == 0:
		priority = WorkplacePriority.Priority.HIGH - stored
	else:
		priority = stored


func berry_count() -> int:
	return stock_count()


func berries_full() -> bool:
	return storage_full()


func withdraw_berries(target: ItemContainer, amount: int) -> int:
	return withdraw_harvest(target, amount)


func change_priority(value: int) -> void:
	if priority == value:
		return
	priority = value
	var game := Game.find(self)
	if game:
		game.rebalance_workplaces()
