extends Structure
class_name Warehouse

const _KEY_MANAGER_ID := 1

var manager_id := 0


func _serialize() -> Dictionary:
	return {_KEY_MANAGER_ID: manager_id}


func _deserialize(data: Dictionary) -> void:
	manager_id = int(data.get(_KEY_MANAGER_ID, 0))


func berry_count() -> int:
	return container.count_of(ItemConfig.TypeId.BERRY)


func withdraw_berries(target: ItemContainer, amount: int) -> int:
	var moved := container.take(ItemConfig.TypeId.BERRY, amount)
	if moved > 0:
		target.add(ItemConfig.TypeId.BERRY, moved)
	return moved


func assign_manager(character: Character) -> void:
	character.workplace_structure_id = id
	character.abandon_ai_tasks()
	manager_id = character.id
