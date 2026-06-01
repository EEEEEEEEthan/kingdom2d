extends Node
class_name Game

const MAP_LEFT_X = 0
const TILE_SIZE = 8
const MAP_CELL_COUNT = 512
const MAP_WIDTH = MAP_CELL_COUNT * TILE_SIZE
const MAP_RIGHT_X = MAP_LEFT_X + MAP_WIDTH
const CAMERA_VIEW_MIN_LEFT_X = MAP_LEFT_X
const CAMERA_VIEW_MAX_RIGHT_X = MAP_RIGHT_X

static func get_position_by_cell_index(cell_index: int) -> int:
	return cell_index * TILE_SIZE

var structure_manager: StructureManager:
	get:
		if not structure_manager: structure_manager = %StructureManager
		return structure_manager

func _ready() -> void:
	pass

func reset_game() -> void:
	pass

func new_game() -> void:
	pass

func load_game() -> void:
	pass

func save_game() -> void:
	pass
