extends Structure
class_name Warehouse

enum StoragePolicy {
	ACCEPT,
	WITHDRAW_ONLY,
	REFUSE,
}

const POLICY_NAMES := ["接收", "只出不进", "不接收"]
const SLOT_COUNT := 1
## 软上限：出发时已满则不启运；到达时仍可入库，允许爆仓。
const BERRY_CAPACITY := 100
const LOG_CAPACITY := 100
const _KEY_POLICIES := 1
const _KEY_PRIORITY := 2

var _policies: Dictionary[int, int] = {}
var priority := WorkplacePriority.Priority.NORMAL


func _serialize() -> Dictionary:
	var pairs: Array = []
	for item_id in _policies:
		pairs.append([item_id, _policies[item_id]])
	return {
		_KEY_POLICIES: pairs,
		_KEY_PRIORITY: priority,
	}


func _deserialize(data: Dictionary) -> void:
	_policies.clear()
	for pair in data.get(_KEY_POLICIES, []):
		_policies[int(pair[0])] = int(pair[1])
	priority = int(data.get(_KEY_PRIORITY, WorkplacePriority.Priority.NORMAL))
	_watch_container()
	_apply_fill()


func policy_of(item_id: int) -> int:
	return _policies.get(item_id, StoragePolicy.ACCEPT)


func set_storage_policy(item_id: int, policy: int) -> void:
	_policies[item_id] = policy


func accepts_deposit(item_id: int) -> bool:
	return policy_of(item_id) == StoragePolicy.ACCEPT


func accepts_withdraw(item_id: int) -> bool:
	return policy_of(item_id) != StoragePolicy.REFUSE


## 找离 origin_cell 最近、且匹配收发条件的仓库。同类距离取更小 id。
static func nearest(
	structure_manager: StructureManager,
	origin_cell: int,
	item_id: int,
	for_deposit := false,
	for_withdraw := false,
	require_stock := false,
	skip_full := false,
) -> Warehouse:
	var nearest_warehouse: Warehouse
	var nearest_distance := 0
	for structure in structure_manager.structures_of_type(StructureConfig.TypeId.WAREHOUSE):
		var warehouse := structure as Warehouse
		if for_deposit and not warehouse.accepts_deposit(item_id):
			continue
		if for_withdraw and not warehouse.accepts_withdraw(item_id):
			continue
		if require_stock and warehouse.container.count_of(item_id) <= 0:
			continue
		if skip_full and warehouse.is_full(item_id):
			continue
		var distance := absi(warehouse.cell_index - origin_cell)
		if nearest_warehouse == null or distance < nearest_distance or (distance == nearest_distance and warehouse.id < nearest_warehouse.id):
			nearest_warehouse = warehouse
			nearest_distance = distance
	return nearest_warehouse


func _ready() -> void:
	super._ready()
	_watch_container()
	_apply_fill()


func _watch_container() -> void:
	if not container.changed.is_connected(_apply_fill):
		container.changed.connect(_apply_fill)


func _apply_fill() -> void:
	var stock := get_node_or_null(^"%Stock") as Sprite2D
	if stock:
		stock.visible = not container.is_empty()


func berry_count() -> int:
	return container.count_of(ItemConfig.TypeId.BERRY)


func log_count() -> int:
	return container.count_of(ItemConfig.TypeId.LOG)


func capacity_of(item_id: int) -> int:
	match item_id:
		ItemConfig.TypeId.BERRY:
			return BERRY_CAPACITY
		ItemConfig.TypeId.LOG:
			return LOG_CAPACITY
		_:
			return 0


func is_full(item_id: int) -> bool:
	var capacity := capacity_of(item_id)
	if capacity <= 0:
		return false
	return container.count_of(item_id) >= capacity


func withdraw_logs(target: ItemContainer, amount: int) -> int:
	if not accepts_withdraw(ItemConfig.TypeId.LOG):
		return 0
	var moved := container.take(ItemConfig.TypeId.LOG, amount)
	if moved > 0:
		target.add(ItemConfig.TypeId.LOG, moved)
	return moved


func withdraw_berries(target: ItemContainer, amount: int) -> int:
	if not accepts_withdraw(ItemConfig.TypeId.BERRY):
		return 0
	var moved := container.take(ItemConfig.TypeId.BERRY, amount)
	if moved > 0:
		target.add(ItemConfig.TypeId.BERRY, moved)
	return moved


func change_priority(value: int) -> void:
	if priority == value:
		return
	priority = value
	var game := Game.find(self)
	if game:
		game.rebalance_workplaces()


func assign_manager(character: Character) -> void:
	var game := Game.find(self)
	if game:
		game.employment.assign(character.id, id)
	character.abandon_ai_tasks()
