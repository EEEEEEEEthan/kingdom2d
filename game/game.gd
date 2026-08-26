extends Node
class_name Game

const TILE_SIZE = 8
const HALF_TILE_SIZE = round(TILE_SIZE / 2.0)
const MAP_CELL_COUNT = 512
const MAP_WIDTH = MAP_CELL_COUNT * TILE_SIZE
const SAVE_FILE_PATH = "user://save.dat"
const _GAME_START_DAYS = 7.25

const _SERKEY_STRUCTURE_MANAGER = 1
const _SERKEY_CHARACTER_MANAGER = 2
const _SERKEY_TERRAIN = 3
const _SERKEY_DAYS = 4

signal character_inspect_requested(character: Character)

static func get_position_by_cell_index(cell_index: int) -> int:
	return cell_index * TILE_SIZE

var game_time: GameTime = GameTime.new(_GAME_START_DAYS)

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
	character_manager.character_inspect_requested.connect(
			character_inspect_requested.emit
	)
	if FileAccess.file_exists(SAVE_FILE_PATH):
		load_game()
	else:
		new_game()


func advance_debug_time_by_hours(hours: float = 1.0) -> void:
	game_time.all_days += hours / 24.0


func _process(dt: float) -> void:
	game_time.all_days += dt * GameTime.REAL_SECONDS_TO_GAME_DAYS

func new_game() -> void:
	_clear()
	GameBuilder.build(self)
	save_game()

func reset_game() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.open("user://").remove(SAVE_FILE_PATH.get_file())
	_clear()
	new_game()

func load_game() -> void:
	print("load_game")
	_clear()
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	var data := file.get_var() as Dictionary
	terrain.deserialize(data.get(_SERKEY_TERRAIN, {}))
	structure_manager.deserialize(data.get(_SERKEY_STRUCTURE_MANAGER, {}))
	character_manager.deserialize(data.get(_SERKEY_CHARACTER_MANAGER, {}))
	game_time.all_days = data.get(_SERKEY_DAYS, _GAME_START_DAYS)

func save_game() -> void:
	print("save_game")
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	var data = {
		_SERKEY_STRUCTURE_MANAGER: structure_manager.serialize(),
		_SERKEY_CHARACTER_MANAGER: character_manager.serialize(),
		_SERKEY_TERRAIN: terrain.serialize(),
		_SERKEY_DAYS: game_time.all_days
	}
	file.store_var(data)

func _clear() -> void:
	game_time.all_days = 0
	structure_manager.clear()
	character_manager.clear()
	terrain.clear()

func reset_camera() -> void:
	%Camera2D.reset_to_center()

func is_map_center_off_screen() -> bool:
	return %Camera2D.is_map_center_off_screen()

func start_build_placement(structure_config: StructureConfig) -> void:
	horizon.add_child(await StructureBuildPlacement.new(self, structure_config))
