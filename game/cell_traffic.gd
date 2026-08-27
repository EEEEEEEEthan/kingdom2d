extends RefCounted
class_name CellTraffic

const _KEY_DAY_INDEX = 1
const _KEY_TODAY = 2
const _KEY_YESTERDAY = 3
const _KEY_LAST_CELL = 4
const _KEY_STALL_CLAIMS = 5

var _day_index := -1
var _today: Array[int] = []
var _yesterday: Array[int] = []
var _last_cell: Dictionary[int, int] = {}
var _stall_claims: Dictionary[int, Vector2i] = {}


func _init() -> void:
	_today = _zero_counts()
	_yesterday = _zero_counts()


func clear() -> void:
	_day_index = -1
	_today = _zero_counts()
	_yesterday = _zero_counts()
	_last_cell.clear()
	_stall_claims.clear()


func tick(game: Game) -> void:
	_sync_day(int(game.game_time.all_days))
	for character in game.character_manager.characters.values():
		_note_enter(
				character.id,
				Game.get_cell_index_by_world_x(character.position.x)
		)


func try_claim_stall(cell_index: int, character: Character, character_manager: CharacterManager) -> bool:
	var current: Vector2i = _stall_claims.get(cell_index, Vector2i.ZERO)
	if _is_claim_live(current, character_manager) and current.x != character.id:
		return false
	_stall_claims[cell_index] = Vector2i(character.id, character.ai_behavior_token)
	return true


func pick_hottest_unclaimed_cell(character_manager: CharacterManager) -> int:
	var counts := _counts_for_stall()
	var best_count := 0
	var best_cell := -1
	for cell_index in Game.MAP_CELL_COUNT:
		var current: Vector2i = _stall_claims.get(cell_index, Vector2i.ZERO)
		if _is_claim_live(current, character_manager):
			continue
		var count: int = counts[cell_index]
		if count > best_count:
			best_count = count
			best_cell = cell_index
	return best_cell


func get_live_stall_cell_indices(character_manager: CharacterManager) -> Array[int]:
	var cells: Array[int] = []
	for cell_index in _stall_claims:
		if _is_claim_live(_stall_claims[cell_index], character_manager):
			cells.append(cell_index)
	cells.sort()
	return cells


func is_character_stalling(character: Character, character_manager: CharacterManager) -> bool:
	for cell_index in _stall_claims:
		var claim: Vector2i = _stall_claims[cell_index]
		if claim.x != character.id:
			continue
		if claim.y != character.ai_behavior_token:
			continue
		if not _is_claim_live(claim, character_manager):
			continue
		return true
	return false


func serialize() -> Dictionary:
	var last_cell_pairs: Array[Array] = []
	for character_id in _last_cell:
		last_cell_pairs.append([character_id, _last_cell[character_id]])
	var stall_rows: Array[Array] = []
	for cell_index in _stall_claims:
		var claim: Vector2i = _stall_claims[cell_index]
		stall_rows.append([cell_index, claim.x, claim.y])
	return {
		_KEY_DAY_INDEX: _day_index,
		_KEY_TODAY: _today.duplicate(),
		_KEY_YESTERDAY: _yesterday.duplicate(),
		_KEY_LAST_CELL: last_cell_pairs,
		_KEY_STALL_CLAIMS: stall_rows,
	}


func deserialize(data: Dictionary) -> void:
	clear()
	_day_index = data.get(_KEY_DAY_INDEX, -1)
	_copy_counts(data.get(_KEY_TODAY), _today)
	_copy_counts(data.get(_KEY_YESTERDAY), _yesterday)
	for pair in data.get(_KEY_LAST_CELL, []):
		_last_cell[int(pair[0])] = int(pair[1])
	for row in data.get(_KEY_STALL_CLAIMS, []):
		_stall_claims[int(row[0])] = Vector2i(int(row[1]), int(row[2]))


func _sync_day(day_index: int) -> void:
	if day_index == _day_index:
		return
	if _day_index >= 0:
		_yesterday = _today.duplicate()
		_today = _zero_counts()
	_day_index = day_index
	_stall_claims.clear()


func _note_enter(character_id: int, cell_index: int) -> void:
	if _last_cell.get(character_id, -1) == cell_index:
		return
	_last_cell[character_id] = cell_index
	_today[cell_index] = _today[cell_index] + 1


func _counts_for_stall() -> Array[int]:
	for count in _yesterday:
		if count > 0:
			return _yesterday
	return _today


func _zero_counts() -> Array[int]:
	var counts: Array[int] = []
	counts.resize(Game.MAP_CELL_COUNT)
	counts.fill(0)
	return counts


func _copy_counts(source, dest: Array[int]) -> void:
	if source == null:
		return
	if source.size() != Game.MAP_CELL_COUNT:
		return
	for cell_index in Game.MAP_CELL_COUNT:
		dest[cell_index] = int(source[cell_index])


func _is_claim_live(claim: Vector2i, character_manager: CharacterManager) -> bool:
	if claim.x <= 0:
		return false
	var character := character_manager.get_character(claim.x)
	if character == null or not is_instance_valid(character):
		return false
	return character.ai_behavior_token == claim.y
