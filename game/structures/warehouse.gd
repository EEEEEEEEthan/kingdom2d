extends Structure
class_name Warehouse

enum StoragePolicy {
	ACCEPT,
	WITHDRAW_ONLY,
	REFUSE,
}

const POLICY_NAMES := ["接收", "只出不进", "不接收"]
const _KEY_POLICIES := 1

var _policies: Dictionary[int, int] = {}


func _serialize() -> Dictionary:
	var pairs: Array = []
	for item_id in _policies:
		pairs.append([item_id, _policies[item_id]])
	return {_KEY_POLICIES: pairs}


func _deserialize(data: Dictionary) -> void:
	_policies.clear()
	for pair in data.get(_KEY_POLICIES, []):
		_policies[int(pair[0])] = int(pair[1])
	_watch_container()
	_apply_fill()


func policy_of(item_id: int) -> int:
	return _policies.get(item_id, StoragePolicy.ACCEPT)


func set_storage_policy(item_id: int, policy: int) -> void:
	_policies[item_id] = policy


func accepts_deposit(item_id: int) -> bool:
	return policy_of(item_id) == StoragePolicy.ACCEPT


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
	var moved := container.take(ItemConfig.TypeId.BERRY, amount)
	if moved > 0:
		target.add(ItemConfig.TypeId.BERRY, moved)
	return moved


func assign_manager(character: Character) -> void:
	var game := Game.find(self)
	if game:
		game.employment.assign(character.id, id)
	character.abandon_ai_tasks()
