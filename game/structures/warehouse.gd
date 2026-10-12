extends Structure
class_name Warehouse

const _KEY_MANAGER_ID := 1


func _serialize() -> Dictionary:
	return {}


func _deserialize(_data: Dictionary) -> void:
	_watch_container()
	_apply_fill()


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
