extends Node
class_name Game

const MAP_LEFT_X = 0
const TILE_SIZE = 8
const MAP_CELL_COUNT = 512
const MAP_WIDTH = MAP_CELL_COUNT * TILE_SIZE
const MAP_RIGHT_X = MAP_LEFT_X + MAP_WIDTH
const CAMERA_VIEW_MIN_LEFT_X = MAP_LEFT_X
const CAMERA_VIEW_MAX_RIGHT_X = MAP_RIGHT_X
const SAVE_FILE_PATH = "user://save.dat"

const _SERKEY_STRUCTURE_MANAGER = 1

static func get_position_by_cell_index(cell_index: int) -> int:
	return cell_index * TILE_SIZE

var structure_manager: StructureManager:
	get:
		if not structure_manager: structure_manager = %StructureManager
		return structure_manager

func _ready() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		load_game()
	else:
		new_game()

func reset_game() -> void:
	structure_manager.reset()

func new_game() -> void:
	reset_game()

func load_game() -> void:
	reset_game()
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	var data := file.get_var() as Dictionary
	structure_manager.deserialize(data[_SERKEY_STRUCTURE_MANAGER])

func save_game() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	var data = {
		_SERKEY_STRUCTURE_MANAGER: structure_manager.serialize(),
	}
	file.store_var(data)
