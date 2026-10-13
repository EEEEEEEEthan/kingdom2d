extends Structure
class_name LumberCamp

enum Priority {
	LOW,
	NORMAL,
	HIGH,
}

const SLOT_COUNT := 2
const LOG_CAPACITY := 10
const HAUL_BATCH := 10
const PRIORITY_NAMES := ["低优先", "普通", "高优先"]
const _KEY_PRIORITY := 1

var priority := Priority.NORMAL


func _serialize() -> Dictionary:
	return {
		_KEY_PRIORITY: priority,
	}


func _deserialize(data: Dictionary) -> void:
	priority = int(data.get(_KEY_PRIORITY, Priority.NORMAL))


func log_count() -> int:
	return container.count_of(ItemConfig.TypeId.LOG)


func logs_full() -> bool:
	return log_count() >= LOG_CAPACITY


func withdraw_logs(target: ItemContainer, amount: int) -> int:
	var moved := container.take(ItemConfig.TypeId.LOG, amount)
	if moved > 0:
		target.add(ItemConfig.TypeId.LOG, moved)
	return moved


func deposit_carried(source: ItemContainer) -> void:
	source.transfer_all_to(container)


func change_priority(value: int) -> void:
	if priority == value:
		return
	priority = value
	var game := Game.find(self)
	if game:
		game.rebalance_workplaces()
