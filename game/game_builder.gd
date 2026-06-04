extends RefCounted
class_name GameBuilder

const _OAK_SPAWN_COUNT_MIN = 24
const _OAK_SPAWN_COUNT_MAX = 96
const _CHARACTER_SCENE = preload("res://game/characters/character.tscn")
const _CHARACTER_SPAWN_COUNT = 8
const _CHARACTER_SPAWN_RADIUS = 8


static func build(game) -> void:
	game.clear()
	game.terrain.fill_terrain(Terrain.TerrainType.Land)
	_spawn_sovereign_banner(game)
	_spawn_initial_characters(game)
	_spawn_random_oaks(game)


static func _map_center_cell_index() -> int:
	return Game.MAP_CELL_COUNT / 2


static func _spawn_sovereign_banner(game) -> void:
	var structure_manager := game.structure_manager as StructureManager
	var banner := StructureConfig.sovereign_banner.instantiate() as Structure
	structure_manager.add_structure(banner, _map_center_cell_index())


static func _spawn_initial_characters(game) -> void:
	randomize()
	var character_manager := game.character_manager as CharacterManager
	var center_cell_index := _map_center_cell_index()
	var candidate_cell_indices: Array[int] = []
	for offset in range(-_CHARACTER_SPAWN_RADIUS, _CHARACTER_SPAWN_RADIUS + 1):
		if offset == 0:
			continue
		var cell_index := center_cell_index + offset
		if cell_index < 0 or cell_index >= Game.MAP_CELL_COUNT:
			continue
		candidate_cell_indices.append(cell_index)
	candidate_cell_indices.shuffle()
	var spawn_count := mini(_CHARACTER_SPAWN_COUNT, candidate_cell_indices.size())
	for index in spawn_count:
		var character := _CHARACTER_SCENE.instantiate() as Character
		var cell_index := candidate_cell_indices[index]
		character.position.x = Game.get_position_by_cell_index(cell_index) + Game.HALF_TILE_SIZE
		character_manager.add_character(character)


static func _spawn_random_oaks(game) -> void:
	randomize()
	var structure_manager := game.structure_manager as StructureManager
	var oak_spawn_count := randi_range(_OAK_SPAWN_COUNT_MIN, _OAK_SPAWN_COUNT_MAX)
	var empty_cell_indices: Array[int] = []
	for cell_index in game.MAP_CELL_COUNT:
		if not structure_manager.index_to_structures[cell_index]:
			empty_cell_indices.append(cell_index)
	empty_cell_indices.shuffle()
	var placed_count := mini(oak_spawn_count, empty_cell_indices.size())
	for index in placed_count:
		var oak := StructureConfig.oak.instantiate() as Structure
		structure_manager.add_structure(oak, empty_cell_indices[index])
