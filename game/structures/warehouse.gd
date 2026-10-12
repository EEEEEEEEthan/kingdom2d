extends Structure
class_name Warehouse

const _KEY_MANAGER_ID := 1

var manager_id := 0


func _serialize() -> Dictionary:
	return {_KEY_MANAGER_ID: manager_id}


func _deserialize(data: Dictionary) -> void:
	manager_id = int(data.get(_KEY_MANAGER_ID, 0))


func assign_manager(character: Character) -> void:
	character.workplace_structure_id = id
	character.abandon_ai_tasks()
	manager_id = character.id
