extends Structure
class_name Warehouse

enum Priority {
	LOW,
	NORMAL,
	HIGH,
}

const PRIORITY_NAMES := ["低优先", "普通", "高优先"]
const _KEY_PRIORITY := 2

var priority := Priority.NORMAL


func _serialize() -> Dictionary:
	return {_KEY_PRIORITY: priority}


func _deserialize(data: Dictionary) -> void:
	priority = int(data.get(_KEY_PRIORITY, Priority.NORMAL))


func change_priority(value: int) -> void:
	priority = clampi(value, Priority.LOW, Priority.HIGH)


func berry_count() -> int:
	return container.count_of(ItemConfig.TypeId.BERRY)


func withdraw_berries(target: ItemContainer, amount: int) -> int:
	var moved := container.take(ItemConfig.TypeId.BERRY, amount)
	if moved > 0:
		target.add(ItemConfig.TypeId.BERRY, moved)
	return moved


func assign_manager(character: Character) -> void:
	var game := Game.find(self)
	if game:
		game.employment.assign(character.id, id)
	character.abandon_ai_tasks()
