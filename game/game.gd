extends Node
class_name Game

const TILE_SIZE = 8
const HALF_TILE_SIZE = round(TILE_SIZE / 2.0)
const MAP_CELL_COUNT = 512
const MAP_WIDTH = MAP_CELL_COUNT * TILE_SIZE
const SAVE_FILE_PATH = "user://save.dat"

const _SERKEY_STRUCTURE_MANAGER = 1

static func get_position_by_cell_index(cell_index: int) -> int:
	return cell_index * TILE_SIZE

var horizon: Node2D:
	get:
		if not horizon: horizon = %Horizon
		return horizon

var structure_manager: StructureManager:
	get:
		if not structure_manager: structure_manager = %StructureManager
		return structure_manager

var terrain: Terrain:
	get:
		if not terrain: terrain = %Terrain
		return terrain

var character_manager: CharacterManager:
	get:
		if not character_manager: character_manager = %CharacterManager
		return character_manager

@export var view_height: float:
	set(value):
		view_height = value
		if not is_node_ready():
			await ready
		%Terrain.view_height = value

func _ready() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		load_game()
	else:
		new_game()

func new_game() -> void:
	clear()
	GameBuilder.build(self)
	save_game()

func reset_game() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.open("user://").remove(SAVE_FILE_PATH.get_file())
	new_game()

func load_game() -> void:
	print("load_game")
	clear()
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	var data := file.get_var() as Dictionary
	structure_manager.deserialize(data[_SERKEY_STRUCTURE_MANAGER])

func save_game() -> void:
	print("save_game")
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	var data = {
		_SERKEY_STRUCTURE_MANAGER: structure_manager.serialize(),
	}
	file.store_var(data)

func clear() -> void:
	structure_manager.clear()
	character_manager.clear()
	terrain.clear()

func reset_camera() -> void:
	%Camera2D.reset_to_center()


func is_map_center_off_screen() -> bool:
	return %Camera2D.is_map_center_off_screen()

func start_build_placement(structure_config: StructureConfig) -> void:
	horizon.add_child(await StructureBuildPlacement.new(self, structure_config))
