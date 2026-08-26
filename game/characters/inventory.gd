extends RefCounted
class_name Inventory

const _KEY_ITEM_COUNTS = 1

var item_counts: Dictionary[ItemId.TypeId, int] = {}


func get_item_count(item_id: ItemId.TypeId) -> int:
	return item_counts.get(item_id, 0)


func add_item(item_id: ItemId.TypeId, item_count: int) -> void:
	item_counts[item_id] = get_item_count(item_id) + item_count


func serialize() -> Dictionary:
	return {
		_KEY_ITEM_COUNTS: item_counts.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	item_counts.clear()
	var serialized_counts: Dictionary = data.get(_KEY_ITEM_COUNTS, {})
	for item_id in serialized_counts:
		item_counts[item_id as ItemId.TypeId] = serialized_counts[item_id] as int
