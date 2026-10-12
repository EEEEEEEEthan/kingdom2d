extends Structure
class_name Warehouse

enum StoragePolicy {
	ACCEPT,
	WITHDRAW_ONLY,
	REFUSE,
}

const POLICY_NAMES := ["接收", "只出不进", "不接收"]
const SLOT_COUNT := 1
const _KEY_POLICIES := 1
const _KEY_PRIORITY := 2

var _policies: Dictionary[int, int] = {}
var priority := GathererHut.Priority.NORMAL


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
	priority = int(data.get(_KEY_PRIORITY, GathererHut.Priority.NORMAL))
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
