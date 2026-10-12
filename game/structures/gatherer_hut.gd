extends Structure
class_name GathererHut

enum Priority {
	LOW,
	NORMAL,
	HIGH,
}

const SLOT_COUNT := 2
const BERRY_CAPACITY := 10
const HAUL_BATCH := 10
const PRIORITY_WEIGHTS := [2, 3, 6]
const PRIORITY_NAMES := ["低优先", "普通", "高优先"]
const _KEY_WORKER_IDS := 1
const _KEY_PRIORITY := 2
const _KEY_PRIORITY_ORDER := 3

var priority := Priority.NORMAL


func _serialize() -> Dictionary:
	return {
		_KEY_PRIORITY: priority,
		_KEY_PRIORITY_ORDER: 1,
	}


func _deserialize(data: Dictionary) -> void:
	var stored := int(data.get(_KEY_PRIORITY, Priority.HIGH))
	if int(data.get(_KEY_PRIORITY_ORDER, 0)) == 0:
		priority = Priority.HIGH - stored
	else:
		priority = stored


func berry_count() -> int:
	return container.count_of(ItemConfig.TypeId.BERRY)


func berries_full() -> bool:
	return berry_count() >= BERRY_CAPACITY


func withdraw_berries(target: ItemContainer, amount: int) -> int:
	var moved := container.take(ItemConfig.TypeId.BERRY, amount)
	if moved > 0:
		target.add(ItemConfig.TypeId.BERRY, moved)
	return moved


func deposit_carried(source: ItemContainer) -> void:
	source.transfer_all_to(container)
	if berry_count() > BERRY_CAPACITY:
		container.set_count(ItemConfig.TypeId.BERRY, BERRY_CAPACITY)


func change_priority(value: int) -> void:
	if priority == value:
		return
	priority = value
	var game := Game.find(self)
	if game:
		game.rebalance_workplaces()


# demands 下标是 Priority。先按需求×权重分人，超额从高优先依次流到普通、低优先。
static func allocate_tier_counts(demands: Array, total_people: int) -> Array:
	var result := [0, 0, 0]
	if total_people <= 0:
		return result
	var sum_weight := 0
	for tier in demands.size():
		if int(demands[tier]) > 0:
			sum_weight += int(demands[tier]) * PRIORITY_WEIGHTS[tier]
	if sum_weight == 0:
		return result
	var remainders: Array[Array] = []
	var used := 0
	for tier in demands.size():
		var demand := int(demands[tier])
		if demand <= 0:
			continue
		var numer := total_people * demand * int(PRIORITY_WEIGHTS[tier])
		result[tier] = numer / sum_weight
		used += result[tier]
		remainders.append([numer % sum_weight, tier])
	var leftover := total_people - used
	remainders.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		return a[1] > b[1]
	)
	var cursor := 0
	while leftover > 0 and not remainders.is_empty():
		result[remainders[cursor][1]] += 1
		leftover -= 1
		cursor = (cursor + 1) % remainders.size()
	var carry := 0
	for offset in result.size():
		var tier := result.size() - 1 - offset
		result[tier] += carry
		carry = 0
		var demand := int(demands[tier]) if tier < demands.size() else 0
		if result[tier] > demand:
			carry = result[tier] - demand
			result[tier] = demand
	return result


# 同一优先级里的名额逐个轮流发给还没满的建筑。
static func spread_evenly(total: int, capacities: Array) -> Array:
	var shares: Array[int] = []
	shares.resize(capacities.size())
	shares.fill(0)
	var left := total
	while left > 0:
		var progressed := false
		for index in capacities.size():
			if left <= 0:
				break
			if shares[index] >= int(capacities[index]):
				continue
			shares[index] += 1
			left -= 1
			progressed = true
		if not progressed:
			break
	return shares
