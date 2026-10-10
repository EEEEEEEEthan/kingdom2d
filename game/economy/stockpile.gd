extends RefCounted
class_name Stockpile

## 建筑自己的库存。清空不收货。正常入库受容量限制，爆仓放回不受限制。

enum Policy {
	CLEAR,
	ACCEPT,
	FETCH,
}

const _KEY_CAPACITY = 1
const _KEY_AMOUNTS = 2
const _KEY_POLICIES = 3

var capacity: int = 0
var _amounts: Dictionary = {}
var _policies: Dictionary = {}


func amount(item_id: int) -> int:
	return int(_amounts.get(item_id, 0))


func policy(item_id: int) -> Policy:
	return _policies.get(item_id, Policy.ACCEPT) as Policy


func set_policy(item_id: int, value: Policy) -> void:
	_policies[item_id] = value


func free_space() -> int:
	var used := 0
	for value in _amounts.values():
		used += int(value)
	return maxi(0, capacity - used)


func try_store(item_id: int, count: int) -> bool:
	if count <= 0 or free_space() < count:
		return false
	_amounts[item_id] = amount(item_id) + count
	return true


func can_receive(item_id: int, count: int) -> bool:
	return policy(item_id) != Policy.CLEAR and count > 0 and free_space() >= count


func try_receive(item_id: int, count: int) -> bool:
	if not can_receive(item_id, count):
		return false
	return try_store(item_id, count)


func try_take(item_id: int, count: int) -> bool:
	if count <= 0 or amount(item_id) < count:
		return false
	var left := amount(item_id) - count
	if left == 0:
		_amounts.erase(item_id)
	else:
		_amounts[item_id] = left
	return true


func put_overflow(item_id: int, count: int) -> void:
	if count <= 0:
		return
	_amounts[item_id] = amount(item_id) + count


func serialize() -> Dictionary:
	return {
		_KEY_CAPACITY: capacity,
		_KEY_AMOUNTS: _amounts.duplicate(),
		_KEY_POLICIES: _policies.duplicate(),
	}


func deserialize(data: Dictionary) -> void:
	capacity = int(data.get(_KEY_CAPACITY, capacity))
	_amounts = (data.get(_KEY_AMOUNTS, {}) as Dictionary).duplicate()
	_policies = (data.get(_KEY_POLICIES, {}) as Dictionary).duplicate()
