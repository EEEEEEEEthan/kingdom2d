extends RefCounted
class_name WorkplaceStaffing

## 采集小屋、伐木营地和建筑工会共用这一套编制：按优先级权重把居民分到各工作建筑，再按住址远近减最远、补最近。
## 仓库管理员不进入这池。由 Game 在加人、加工位、改优先级、读档后各调用一次。


static func rebalance(structures: Dictionary[int, Structure], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> void:
	employment.prune(characters, structures)
	var tier_workplaces := _workplaces_by_priority(structures)
	var tier_counts := GathererHut.allocate_tier_counts(_tier_demands(tier_workplaces), _worker_pool_size(structures, characters, employment))
	var targets := _target_counts(tier_workplaces, tier_counts)
	for tier in tier_workplaces:
		for workplace in tier:
			_release_excess(workplace, targets, characters, employment)
	_fill_vacancies(tier_workplaces, targets, characters, employment)


static func _worker_pool_size(structures: Dictionary[int, Structure], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> int:
	var count := 0
	for character in characters.values():
		if structures.get(employment.workplace_of(character.id)) is Warehouse:
			continue
		count += 1
	return count


static func _workplaces_by_priority(structures: Dictionary[int, Structure]) -> Array:
	var tier_workplaces: Array = [[], [], []]
	for structure in structures.values():
		if _is_workplace(structure):
			(tier_workplaces[_priority_of(structure)] as Array).append(structure)
	for tier in tier_workplaces:
		(tier as Array).sort_custom(func(a: Structure, b: Structure) -> bool: return a.id < b.id)
	return tier_workplaces


static func _tier_demands(tier_workplaces: Array) -> Array[int]:
	var demands: Array[int] = []
	for tier in tier_workplaces:
		var demand := 0
		for workplace in tier:
			demand += _slot_count(workplace)
		demands.append(demand)
	return demands


static func _target_counts(tier_workplaces: Array, tier_counts: Array) -> Dictionary[int, int]:
	var targets: Dictionary[int, int] = {}
	for tier in tier_workplaces.size():
		var workplaces: Array = tier_workplaces[tier]
		var capacities: Array[int] = []
		for workplace in workplaces:
			capacities.append(_slot_count(workplace))
		var shares := GathererHut.spread_evenly(tier_counts[tier], capacities)
		for index in workplaces.size():
			targets[(workplaces[index] as Structure).id] = shares[index]
	return targets


static func _release_excess(workplace: Structure, targets: Dictionary[int, int], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> void:
	while employment.count_of(workplace.id) > targets[workplace.id]:
		var farthest := _farthest_worker(workplace, characters, employment)
		if farthest == null:
			break
		employment.release(farthest.id)
		farthest.abandon_ai_tasks()


static func _fill_vacancies(tier_workplaces: Array, targets: Dictionary[int, int], characters: Dictionary[int, Character], employment: WorkplaceIndex) -> void:
	while true:
		var best_workplace: Structure = null
		var best_character: Character = null
		var best_distance := 0
		for tier in tier_workplaces:
			for workplace_value in tier:
				var workplace := workplace_value as Structure
				if employment.count_of(workplace.id) >= targets[workplace.id]:
					continue
				for character_value in characters.values():
					var character := character_value as Character
					if employment.workplace_of(character.id) != 0:
						continue
					var distance := absi(character.resolved_home_cell_index() - workplace.cell_index)
					if best_character != null and distance > best_distance:
						continue
					if best_character != null and distance == best_distance and character.id > best_character.id:
						continue
					if best_character != null and distance == best_distance and character.id == best_character.id and workplace.id > best_workplace.id:
						continue
					best_workplace = workplace
					best_character = character
					best_distance = distance
		if best_character == null:
			return
		employment.assign(best_character.id, best_workplace.id)
		best_character.abandon_ai_tasks()


static func _farthest_worker(workplace: Structure, characters: Dictionary[int, Character], employment: WorkplaceIndex) -> Character:
	var farthest: Character = null
	var farthest_distance := 0
	for worker_id in employment.workers_of(workplace.id):
		var character: Character = characters.get(worker_id)
		if character == null:
			continue
		var distance := absi(character.resolved_home_cell_index() - workplace.cell_index)
		if farthest == null or distance > farthest_distance or (distance == farthest_distance and character.id > farthest.id):
			farthest = character
			farthest_distance = distance
	return farthest


static func _is_workplace(structure: Structure) -> bool:
	if structure == null or not structure.is_built():
		return false
	return structure is GathererHut or structure is LumberCamp or structure is BuildersGuild


static func _priority_of(structure: Structure) -> int:
	if structure is LumberCamp:
		return (structure as LumberCamp).priority
	if structure is BuildersGuild:
		return (structure as BuildersGuild).priority
	return (structure as GathererHut).priority


static func _slot_count(structure: Structure) -> int:
	if structure is LumberCamp:
		return LumberCamp.SLOT_COUNT
	if structure is BuildersGuild:
		return BuildersGuild.SLOT_COUNT
	return GathererHut.SLOT_COUNT
