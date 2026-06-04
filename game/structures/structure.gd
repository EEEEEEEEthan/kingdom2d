extends Node2D
class_name Structure

const _KEY_TYPE_ID = 1
const _KEY_INSTANCE_ID = 2
const _KEY_DATA = 3
const _KEY_CELL_INDEX = 4
const _KEY_HP = 5

var config: StructureConfig
var id: int
var cell_index: int:
	get:
		return cell_index
	set(value):
		cell_index = value
		if not is_node_ready(): await ready
		position = Vector2(value * Game.TILE_SIZE + Game.HALF_TILE_SIZE, 0)
		_on_cell_index_updated()

var active: bool:
	get:
		return id > 0

var hp: int

static func deserialize(data: Dictionary, parent: Node) -> Structure:
	var type_id := data[_KEY_TYPE_ID] as StructureConfig.TypeId
	var structure_config = StructureConfig.configs_by_id.get(type_id)
	if not structure_config:
		printerr("type_id not found: %s" % type_id)
		return null
	var structure := structure_config.instantiate() as Structure
	parent.add_child(structure)
	structure.id = data[_KEY_INSTANCE_ID]
	structure.cell_index = data[_KEY_CELL_INDEX]
	structure.hp = data[_KEY_HP]
	structure._deserialize(data[_KEY_DATA])
	return structure

func _deserialize(_data: Dictionary) -> void:
	pass

func serialize() -> Dictionary:
	return {
		_KEY_TYPE_ID: int(config.id),
		_KEY_INSTANCE_ID: id,
		_KEY_DATA: _serialize(),
		_KEY_CELL_INDEX: cell_index,
		_KEY_HP: hp,
	}

func _serialize() -> Dictionary:
	return {}

func _on_cell_index_updated() -> void:
	pass
