extends Structure
class_name GathererHut

const SLOT_COUNT := 2
const _KEY_WORKER_IDS := 1

var worker_ids: Array[int] = []


func _serialize() -> Dictionary:
	return {_KEY_WORKER_IDS: worker_ids}


func _deserialize(data: Dictionary) -> void:
	worker_ids.clear()
	for worker_id in data.get(_KEY_WORKER_IDS, []):
		worker_ids.append(int(worker_id))


func try_assign_unemployed() -> bool:
	if worker_ids.size() >= SLOT_COUNT:
		return false
	var manager := _game().character_manager
	for character in manager.characters.values():
		if character.workplace_structure_id != 0:
			continue
		character.workplace_structure_id = id
		character.abandon_ai_tasks()
		worker_ids.append(character.id)
		return true
	return false


func _game() -> Game:
	var node: Node = self
	while node:
		if node is Game:
			return node
		node = node.get_parent()
	return null
