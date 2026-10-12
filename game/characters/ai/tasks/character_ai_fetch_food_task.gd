extends CharacterAiTask
class_name CharacterAiFetchFoodTask

## 下班后去最近有食物的仓库，补满住房，再吃掉一天的量。没仓库或没货就直接吃。

const KEY_PHASE = 1
const KEY_WAREHOUSE_ID = 2
const KEY_ATE = 3

var _phase := 0
var _warehouse_id := 0
var _ate := false


func _init(save_payload: Dictionary) -> void:
	_phase = save_payload.get(KEY_PHASE, 0)
	_warehouse_id = save_payload.get(KEY_WAREHOUSE_ID, 0)
	_ate = save_payload.get(KEY_ATE, false)


func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.FETCH_FOOD


func activity_text() -> String:
	if _phase == 1:
		return "正在去仓库"
	if _phase == 2:
		return "正在把食物搬回家"
	return "正在吃饭"


func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	var character := context.character
	var home := Food.home_of(character)
	if home == null:
		return Status.SUCCEEDED
	if _phase == 0:
		var warehouse := Food.nearest_stocked_warehouse(character)
		if Food.space(home) <= 0 or warehouse == null:
			_eat(home)
			return Status.SUCCEEDED
		_warehouse_id = warehouse.id
		_phase = 1
		if character.indoors:
			character.leave_home()
		return Status.RUNNING
	if _phase == 1:
		var warehouse := _warehouse(context)
		if warehouse == null or warehouse.berry_count() <= 0:
			_eat(home)
			return Status.SUCCEEDED
		if character.advance_toward_world_x(delta_seconds, _world_x(warehouse.cell_index)):
			var need := Food.space(home)
			if need > 0:
				warehouse.withdraw_berries(character.carried_items, need)
			_phase = 2
		return Status.RUNNING
	if character.advance_toward_world_x(delta_seconds, _world_x(character.resolved_home_cell_index())):
		Food.deposit(home, character.carried_items)
		_eat(home)
		return Status.SUCCEEDED
	return Status.RUNNING


func on_exit(context: CharacterAiContext) -> void:
	var character := context.character
	var home := Food.home_of(character)
	if home == null:
		return
	Food.deposit(home, character.carried_items)
	_eat(home)


func _eat(home: Structure) -> void:
	if _ate:
		return
	Food.eat(home)
	_ate = true


func _warehouse(context: CharacterAiContext) -> Warehouse:
	return context.structure_manager().get_structure_by_id(_warehouse_id) as Warehouse


func _world_x(cell_index: int) -> float:
	return Game.get_position_by_cell_index(cell_index) + Game.HALF_TILE_SIZE


func _serialize_payload() -> Dictionary:
	return {
		KEY_PHASE: _phase,
		KEY_WAREHOUSE_ID: _warehouse_id,
		KEY_ATE: _ate,
	}
