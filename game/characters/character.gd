@tool
extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2
const _KEY_AI_TASK_STACK = 3
const _KEY_INVENTORY = 4
const _KEY_OCCUPATION = 5

signal inspect_requested

var id: int
var occupation: OccupationId.TypeId = OccupationId.TypeId.NONE
var inventory := Inventory.new()

@export var outline: Color = Color.TRANSPARENT:
	set(value):
		if outline == value:
			return
		outline = value
		if not is_node_ready():
			await ready
		%Sprite2D.outline = outline

func advance_toward_world_x(delta_seconds: float, target_world_x: float) -> bool:
	var offset := target_world_x - position.x
	if is_zero_approx(offset):
		return true
	var step := 6.0 * delta_seconds
	if absf(offset) <= step:
		position.x = target_world_x
		return true
	position.x += signf(offset) * step
	return false

func get_ai_behavior_text() -> String:
	return %AiBrain.get_behavior_text()


func get_ai_work_progress_ratio() -> float:
	return %AiBrain.get_work_progress_ratio()


func deserialize(data: Dictionary) -> void:
	id = data[_KEY_ID]
	position = Vector2(data[_KEY_POSITION], 0)
	occupation = data.get(_KEY_OCCUPATION, OccupationId.TypeId.NONE) as OccupationId.TypeId
	if occupation == OccupationId.TypeId.NONE:
		occupation = (
				OccupationId.TypeId.LUMBERJACK
				if id % 2 == 1
				else OccupationId.TypeId.SCAVENGER
		)
	%AiBrain.deserialize(data.get(_KEY_AI_TASK_STACK, {}))
	if data.has(_KEY_INVENTORY):
		inventory.deserialize(data[_KEY_INVENTORY])
	else:
		inventory.add_item(
				ItemTypeId.TypeId.IRON_COIN,
				randi_range(0, 100)
		)

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x,
		_KEY_AI_TASK_STACK: %AiBrain.serialize(),
		_KEY_INVENTORY: inventory.serialize(),
		_KEY_OCCUPATION: occupation,
	}
