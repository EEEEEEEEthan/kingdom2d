extends HarvestWorkplace
class_name LumberCamp

const SLOT_COUNT := 2
const LOG_CAPACITY := 10
const _KEY_PRIORITY := 1

var priority := WorkplacePriority.Priority.NORMAL


func harvest_item_id() -> int:
	return ItemConfig.TypeId.LOG


func harvest_plant_type_id() -> int:
	return StructureConfig.TypeId.OAK


func harvest_capacity() -> int:
	return LOG_CAPACITY


func _serialize() -> Dictionary:
	return {
		_KEY_PRIORITY: priority,
	}


func _deserialize(data: Dictionary) -> void:
	priority = int(data.get(_KEY_PRIORITY, WorkplacePriority.Priority.NORMAL))


func log_count() -> int:
	return stock_count()


func logs_full() -> bool:
	return storage_full()


func withdraw_logs(target: ItemContainer, amount: int) -> int:
	return withdraw_harvest(target, amount)


func change_priority(value: int) -> void:
	if priority == value:
		return
	priority = value
	var game := Game.find(self)
	if game:
		game.rebalance_workplaces()
