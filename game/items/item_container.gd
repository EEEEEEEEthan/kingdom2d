extends RefCounted
class_name ItemContainer

## 按物品类型累计存储，数量不限。

const _KEY_COUNTS = 1

var _counts: Dictionary[int, int] = {}


func add(item_id: int, amount: int = 1) -> void:
	if amount <= 0:
		return
	_counts[item_id] = count_of(item_id) + amount


func set_count(item_id: int, amount: int) -> void:
	if amount <= 0:
		_counts.erase(item_id)
		return
	_counts[item_id] = amount


func count_of(item_id: int) -> int:
	return _counts.get(item_id, 0)


func item_ids() -> Array[int]:
	var ids: Array[int] = []
	for item_id in _counts:
		ids.append(item_id)
	ids.sort()
	return ids


func is_empty() -> bool:
	return _counts.is_empty()


func transfer_all_to(target: ItemContainer) -> void:
	for item_id in item_ids():
		target.add(item_id, count_of(item_id))
	_counts.clear()


func serialize() -> Dictionary:
	return {_KEY_COUNTS: _counts}


static func deserialize(data: Dictionary) -> ItemContainer:
	var container := ItemContainer.new()
	var counts: Dictionary = data.get(_KEY_COUNTS, {})
	for item_id in counts:
		container.add(int(item_id), int(counts[item_id]))
	return container
