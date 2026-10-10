extends CharacterAiTask
class_name CharacterAiWorkUnitTask

var _unit: LogisticsUnit
var _host: _Mover


func _init(save_payload: Dictionary) -> void:
	_unit = LogisticsUnit.from_payload(save_payload)


func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.WORK_UNIT


func on_enter(context: CharacterAiContext) -> void:
	var game := _game(context)
	_unit.find_site = func(site_id: int):
		return game.structure_manager.get_structure_by_id(site_id)
	_unit.list_warehouses = func():
		var found: Array = []
		for structure in game.structure_manager.index_to_structures:
			if structure is WorkSite and (structure as WorkSite).kind == WorkSite.Kind.WAREHOUSE:
				found.append(structure)
		return found
	_host = _Mover.new(context.character)


func tick(delta_seconds: float, _context: CharacterAiContext) -> Status:
	if _unit.tick(delta_seconds, _host):
		return Status.SUCCEEDED
	return Status.RUNNING


func on_exit(_context: CharacterAiContext) -> void:
	if _unit.phase != LogisticsUnit.Phase.DONE:
		_unit.refund()


func _serialize_payload() -> Dictionary:
	return _unit.to_payload()


func _game(context: CharacterAiContext) -> Game:
	var node: Node = context.character
	while node:
		if node is Game:
			return node
		node = node.get_parent()
	return null


class _Mover:
	var character: Character

	func _init(owner_character: Character) -> void:
		character = owner_character

	var x: float:
		get:
			return character.position.x
		set(value):
			character.position.x = value

	var speed: float:
		get:
			return character.move_speed_pixels_per_second
