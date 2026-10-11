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


func has_open_slot() -> bool:
	return worker_ids.size() < SLOT_COUNT


func assign_worker(character: Character) -> void:
	character.workplace_structure_id = id
	character.abandon_ai_tasks()
	worker_ids.append(character.id)


func _game() -> Game:
	var node: Node = self
	while node:
		if node is Game:
			return node
		node = node.get_parent()
	return null
