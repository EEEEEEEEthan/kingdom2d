extends RefCounted
class_name GameBuilder

const _OAK_SPAWN_COUNT_MIN = 24
const _OAK_SPAWN_COUNT_MAX = 96


static func build(game) -> void:
	game.clear()
	game.terrain.fill_terrain(Terrain.TerrainType.Land)
	_spawn_random_oaks(game)


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
