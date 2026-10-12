extends RefCounted
class_name WorkplaceStaffing

## 采集小屋的岗位编制：按优先级权重把居民分到各小屋，再按住址远近减最远、补最近。
## 由 Game 在加人、加小屋、改优先级、读档后各调用一次。


static func rebalance(structures: Dictionary[int, Structure], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> void:
	employment.prune(characters, structures)
	var tier_huts := _huts_by_priority(structures)
	var tier_counts := GathererHut.allocate_tier_counts(_tier_demands(tier_huts), _gatherer_pool_size(structures, characters, employment))
	var targets := _target_counts(tier_huts, tier_counts)
	for tier in tier_huts:
		for hut in tier:
			_release_excess(hut, targets, characters, employment)
	_fill_vacancies(tier_huts, targets, characters, employment)


# 仓库管理员不进采集编制。
static func _gatherer_pool_size(structures: Dictionary[int, Structure], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> int:
	var count := 0
	for character in characters.values():
		if structures.get(employment.workplace_of(character.id)) is Warehouse:
			continue
		count += 1
	return count


# 每个优先级一个列表，各自按 id 排序，保证分配次序稳定。
static func _huts_by_priority(structures: Dictionary[int, Structure]) -> Array:
	var tier_huts: Array = [[], [], []]
	for structure in structures.values():
		if structure is GathererHut:
			var hut := structure as GathererHut
			(tier_huts[hut.priority] as Array).append(hut)
	for tier in tier_huts:
		(tier as Array).sort_custom(func(a: GathererHut, b: GathererHut) -> bool: return a.id < b.id)
	return tier_huts


static func _tier_demands(tier_huts: Array) -> Array[int]:
	var demands: Array[int] = []
	for tier in tier_huts:
		demands.append((tier as Array).size() * GathererHut.SLOT_COUNT)
	return demands


# 每个小屋的目标人数：先按权重分到各优先级，再在优先级内轮流发名额。
static func _target_counts(tier_huts: Array, tier_counts: Array) -> Dictionary[int, int]:
	var targets: Dictionary[int, int] = {}
	for tier in tier_huts.size():
		var huts: Array = tier_huts[tier]
		var capacities: Array[int] = []
		capacities.resize(huts.size())
		capacities.fill(GathererHut.SLOT_COUNT)
		var shares := GathererHut.spread_evenly(tier_counts[tier], capacities)
		for index in huts.size():
			targets[(huts[index] as GathererHut).id] = shares[index]
	return targets


# 超编的先辞退家最远的。
static func _release_excess(hut: GathererHut, targets: Dictionary[int, int], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> void:
	while employment.count_of(hut.id) > targets[hut.id]:
		var farthest := _farthest_worker(hut, characters, employment)
		if farthest == null:
			break
		employment.release(farthest.id)
		farthest.abandon_ai_tasks()


# 缺编的每次补一个家最近的无业居民；距离相同先看居民 id，再看小屋 id。
static func _fill_vacancies(tier_huts: Array, targets: Dictionary[int, int], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> void:
	while true:
		var best_hut: GathererHut = null
		var best_character: Character = null
		var best_distance := 0
		for tier in tier_huts:
			for hut_value in tier:
				var hut := hut_value as GathererHut
				if employment.count_of(hut.id) >= targets[hut.id]:
					continue
				for character_value in characters.values():
					var character := character_value as Character
					if employment.workplace_of(character.id) != 0:
						continue
					var distance := absi(character.resolved_home_cell_index() - hut.cell_index)
					if best_character != null and distance > best_distance:
						continue
					if best_character != null and distance == best_distance and character.id > best_character.id:
						continue
					if best_character != null and distance == best_distance and character.id == best_character.id and hut.id > best_hut.id:
						continue
					best_hut = hut
					best_character = character
					best_distance = distance
		if best_character == null:
			return
		employment.assign(best_character.id, best_hut.id)
		best_character.abandon_ai_tasks()


static func _farthest_worker(hut: GathererHut, characters: Dictionary[int, Character], employment: WorkplaceIndex) -> Character:
	var farthest: Character = null
	var farthest_distance := 0
	for worker_id in employment.workers_of(hut.id):
		var character: Character = characters.get(worker_id)
		if character == null:
			continue
		var distance := absi(character.resolved_home_cell_index() - hut.cell_index)
		if farthest == null or distance > farthest_distance or (distance == farthest_distance and character.id > farthest.id):
			farthest = character
			farthest_distance = distance
	return farthest
