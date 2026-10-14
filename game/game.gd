extends Node
class_name Game

const TILE_SIZE = 8
const HALF_TILE_SIZE = round(TILE_SIZE / 2.0)
const MAP_CELL_COUNT = 512
const MAP_WIDTH = MAP_CELL_COUNT * TILE_SIZE
const SAVE_FILE_PATH = "user://save.dat"
const _SAVE_TEMP_PATH = "user://save.dat.tmp"
const _GAME_START_DAYS = 7.25

static func get_position_by_cell_index(cell_index: int) -> int:
	return cell_index * TILE_SIZE

static func find(node: Node) -> Game:
	var current := node
	while current:
		if current is Game:
			return current
		current = current.get_parent()
	return null

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

var employment := WorkplaceIndex.new()

var character_manager: CharacterManager:
	get:
		if not character_manager: character_manager = %CharacterManager
		return character_manager

var _save_pending := false

@export var view_height: float:
	set(value):
		view_height = value
		if not is_node_ready():
			await ready
		%Terrain.view_height = value
		%CelestialLayer.offset = Vector2(0, %Terrain.celestial_drop_y(value))

func advance_debug_time_by_hours(hours: float = 1.0) -> void:
	game_time.all_days += hours / 24.0


func _process(dt: float) -> void:
	game_time.all_days += dt * GameTime.REAL_SECONDS_TO_GAME_DAYS
	if _save_pending:
		_save_pending = false
		_write_save()

func request_save() -> void:
	_save_pending = true

func new_game() -> void:
	_boot_world(true)

func reset_game() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.open("user://").remove(SAVE_FILE_PATH.get_file())
	_clear()
	new_game()

func _boot_world(persist: bool) -> void:
	_clear()
	GameBuilder.build(self)
	if persist:
		request_save()

func _ready() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		if not load_game():
			# 整档不是字典：不写盘，原文件留着。
			_boot_world(false)
	else:
		new_game()

func load_game() -> bool:
	print("load_game")
	var parsed = _read_save_variant()
	if not parsed is Dictionary:
		return false
	_clear()
	_apply_save(parsed)
	return true

func _read_save_variant() -> Variant:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed = file.get_var()
	file.close()
	return parsed

func _apply_save(data: Dictionary) -> void:
	var save_version := int(data.get(SaveFormat.SECTION_VERSION, 0))
	var terrain_data = data.get(SaveFormat.SECTION_TERRAIN, {})
	if terrain_data is Dictionary:
		terrain.deserialize(terrain_data)
	var structures_data = data.get(SaveFormat.SECTION_STRUCTURES, {})
	if not structures_data is Dictionary:
		structures_data = {}
	structure_manager.deserialize(structures_data, save_version)
	var characters_data = data.get(SaveFormat.SECTION_CHARACTERS, {})
	if not characters_data is Dictionary:
		characters_data = {}
	character_manager.deserialize(characters_data)
	var employment_data = data.get(SaveFormat.SECTION_EMPLOYMENT, null)
	if employment_data is Dictionary:
		employment.deserialize(employment_data)
	else:
		employment.import_legacy(
			structures_data,
			characters_data,
			character_manager.characters,
			structure_manager.structures
		)
	game_time.all_days = float(data.get(SaveFormat.SECTION_DAYS, _GAME_START_DAYS))
	rebalance_workplaces()

func _write_save() -> void:
	var file := FileAccess.open(_SAVE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		_save_pending = true
		return
	var stored := file.store_var({
		SaveFormat.SECTION_VERSION: SaveFormat.VERSION,
		SaveFormat.SECTION_STRUCTURES: structure_manager.serialize(),
		SaveFormat.SECTION_CHARACTERS: character_manager.serialize(),
		SaveFormat.SECTION_TERRAIN: terrain.serialize(),
		SaveFormat.SECTION_DAYS: game_time.all_days,
		SaveFormat.SECTION_EMPLOYMENT: employment.serialize(),
	})
	file.flush()
	file.close()
	if not stored or DirAccess.rename_absolute(_SAVE_TEMP_PATH, SAVE_FILE_PATH) != OK:
		_save_pending = true

func _clear() -> void:
	game_time.all_days = 0
	employment.clear()
	structure_manager.clear()
	character_manager.clear()
	terrain.clear()

func set_inspect_focus(target: Node2D) -> void:
	%Camera2D.follow(target)
	HoverOutline.pin(target)


func reset_camera() -> void:
	%Camera2D.reset_to_center()

func is_map_center_off_screen() -> bool:
	return %Camera2D.is_map_center_off_screen()

signal structure_open_requested(structure: Structure)
signal character_open_requested(character: Character)

const _CLICK_DRAG_THRESHOLD_PX := 4.0

var _left_press_position := Vector2.ZERO
var _left_press_pending := false

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _build_placement_active():
		_left_press_pending = false
		return
	if mouse_button.pressed:
		_left_press_pending = true
		_left_press_position = mouse_button.position
		return
	if not _left_press_pending:
		return
	_left_press_pending = false
	if mouse_button.position.distance_to(_left_press_position) > _CLICK_DRAG_THRESHOLD_PX:
		return
	var character := _character_under_mouse()
	if character:
		get_viewport().set_input_as_handled()
		character_open_requested.emit(character)
		return
	var structure := _structure_under_mouse()
	if structure:
		get_viewport().set_input_as_handled()
		structure_open_requested.emit(structure)


func _build_placement_active() -> bool:
	for child in horizon.get_children():
		if child is StructureBuildPlacement:
			return true
	return false


func _character_under_mouse() -> Character:
	return HoverOutline.hovered_host() as Character


func _structure_under_mouse() -> Structure:
	return HoverOutline.hovered_host() as Structure


func start_build_placement(structure_config: StructureConfig) -> void:
	horizon.add_child(await StructureBuildPlacement.new(self, structure_config))


func spawn_resident_at_cell(cell_index: int) -> Character:
	var character := character_manager.create_character()
	character.home_cell_index = cell_index
	character.position.x = get_position_by_cell_index(cell_index) + HALF_TILE_SIZE
	rebalance_workplaces()
	return character


func rebalance_workplaces() -> void:
	WorkplaceStaffing.rebalance(structure_manager.structures, character_manager.characters, employment)
