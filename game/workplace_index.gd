extends RefCounted
class_name WorkplaceIndex

## 居民与工作建筑的唯一关系。角色和建筑上都不再记这份名单。

const _KEY_PAIRS = 1

var _workplace_of: Dictionary[int, int] = {}
var _workers_of: Dictionary[int, Array] = {}


func workplace_of(character_id: int) -> int:
	return _workplace_of.get(character_id, 0)


func workers_of(structure_id: int) -> Array[int]:
	var stored: Array = _workers_of.get(structure_id, [])
	var workers: Array[int] = []
	workers.assign(stored)
	return workers


func count_of(structure_id: int) -> int:
	return (_workers_of.get(structure_id, []) as Array).size()


func assign(character_id: int, structure_id: int) -> void:
	if character_id <= 0 or structure_id <= 0:
		return
	release(character_id)
	_workplace_of[character_id] = structure_id
	if not _workers_of.has(structure_id):
		_workers_of[structure_id] = []
	(_workers_of[structure_id] as Array).append(character_id)


func release(character_id: int) -> void:
	if not _workplace_of.has(character_id):
		return
	var structure_id := _workplace_of[character_id]
	_workplace_of.erase(character_id)
	var workers: Array = _workers_of.get(structure_id, [])
	workers.erase(character_id)
	if workers.is_empty():
		_workers_of.erase(structure_id)


func release_structure(structure_id: int) -> void:
	for character_id in workers_of(structure_id):
		release(character_id)


func clear() -> void:
	_workplace_of.clear()
	_workers_of.clear()


func prune(characters: Dictionary, structures: Dictionary) -> void:
	var stale: Array[int] = []
	for character_id in _workplace_of:
		var structure_id := _workplace_of[character_id]
		if not characters.has(character_id) or not structures.has(structure_id):
			stale.append(character_id)
	for character_id in stale:
		release(character_id)


func serialize() -> Dictionary:
	return {_KEY_PAIRS: _pairs()}


func deserialize(data: Dictionary) -> void:
	clear()
	for pair in data.get(_KEY_PAIRS, []):
		assign(int(pair[0]), int(pair[1]))


# 旧档把同一关系写在小屋 worker_ids 和角色 workplace_structure_id 上。只留下两边对得上、实体还在的。
func import_legacy(structure_manager_data: Dictionary, character_manager_data: Dictionary, characters: Dictionary, structures: Dictionary) -> void:
	clear()
	var lists := _legacy_worker_lists(structure_manager_data)
	var claims := _legacy_workplace_claims(character_manager_data)
	for character_id in claims:
		var structure_id: int = claims[character_id]
		if not characters.has(character_id) or not structures.has(structure_id):
			continue
		var listed: Array = lists.get(structure_id, [])
		if listed.has(character_id):
			assign(character_id, structure_id)
	for structure_id in lists:
		if not structures.has(structure_id):
			continue
		for character_id in lists[structure_id]:
			if not characters.has(character_id) or workplace_of(character_id) != 0:
				continue
			var claim := int(claims.get(character_id, 0))
			if claim != 0 and claim != structure_id and structures.has(claim):
				var other: Array = lists.get(claim, [])
				if other.has(character_id):
					continue
			assign(character_id, structure_id)


func _pairs() -> Array:
	var structure_ids: Array[int] = []
	for structure_id in _workers_of:
		structure_ids.append(structure_id)
	structure_ids.sort()
	var pairs: Array = []
	for structure_id in structure_ids:
		for character_id in _workers_of[structure_id]:
			pairs.append([character_id, structure_id])
	return pairs


func _legacy_worker_lists(manager: Dictionary) -> Dictionary:
	var lists: Dictionary = {}
	for item in manager.get(StructureManager._KEY_STRUCTURES, []):
		var structure_id := int(item.get(Structure._KEY_INSTANCE_ID, 0))
		var payload: Dictionary = item.get(Structure._KEY_DATA, {})
		var raw = payload.get(GathererHut._KEY_WORKER_IDS, [])
		if raw is Array:
			if raw.is_empty():
				continue
			var ids: Array[int] = []
			for worker_id in raw:
				ids.append(int(worker_id))
			lists[structure_id] = ids
		elif int(raw) > 0:
			lists[structure_id] = [int(raw)]
	return lists


func _legacy_workplace_claims(manager: Dictionary) -> Dictionary:
	var claims: Dictionary = {}
	for item in manager.get(CharacterManager._KEY_CHARACTERS, []):
		var character_id := int(item.get(Character._KEY_ID, 0))
		var structure_id := int(item.get(Character._KEY_WORKPLACE_STRUCTURE_ID, 0))
		if character_id > 0 and structure_id > 0:
			claims[character_id] = structure_id
	return claims
