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
		%CelestialLayer.offset = Vector2(0, %Terrain.celestial_drop_y(value))

func _ready() -> void:
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

signal gatherer_hut_open_requested(hut: GathererHut)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _build_placement_active():
		return
	var hut := _gatherer_hut_under_mouse()
	if not hut:
		return
	get_viewport().set_input_as_handled()
	gatherer_hut_open_requested.emit(hut)


func _build_placement_active() -> bool:
	for child in horizon.get_children():
		if child is StructureBuildPlacement:
			return true
	return false


func _gatherer_hut_under_mouse() -> GathererHut:
	var local: Vector2 = structure_manager.get_global_transform().affine_inverse() * structure_manager.get_global_mouse_position()
	var cell_index := roundi((local.x - HALF_TILE_SIZE) / float(TILE_SIZE))
	for offset in range(-1, 2):
		var index := cell_index + offset
		if index < 0 or index >= MAP_CELL_COUNT:
			continue
		var structure := structure_manager.index_to_structures[index]
		if not structure is GathererHut:
			continue
		var hut_x := float(get_position_by_cell_index(index) + HALF_TILE_SIZE)
		if absf(local.x - hut_x) <= 8.0:
			return structure as GathererHut
	return null


func start_build_placement(structure_config: StructureConfig) -> void:
	horizon.add_child(await StructureBuildPlacement.new(self, structure_config))


func spawn_resident_at_cell(cell_index: int) -> Character:
	var character := character_manager.create_character()
	character.home_cell_index = cell_index
	character.position.x = get_position_by_cell_index(cell_index) + HALF_TILE_SIZE
	return character
