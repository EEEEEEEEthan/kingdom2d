extends RefCounted
class_name GameBuilder

const _OAK_SPAWN_COUNT_MIN = 24
const _OAK_SPAWN_COUNT_MAX = 96
const _BUSH_SPAWN_COUNT_MIN = 48
const _BUSH_SPAWN_COUNT_MAX = 160
const _BUSH_NOISE_FREQUENCY = 0.012
const _BUSH_NOISE_CLUSTER_POWER = 4.0
const _CHARACTER_SPAWN_COUNT = 8
const _CHARACTER_SPAWN_RADIUS = 8


static func build(game) -> void:
	game.terrain.fill_terrain(Terrain.TerrainType.Land)
	_spawn_sovereign_banner(game)
	_spawn_initial_characters(game)
	_spawn_random_oaks(game)
	_spawn_clustered_bushes(game)


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
		var character := character_manager.create_character()
		var cell_index := candidate_cell_indices[index]
		character.position.x = Game.get_position_by_cell_index(cell_index) + Game.HALF_TILE_SIZE


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


static func _spawn_clustered_bushes(game) -> void:
	randomize()
	var structure_manager := game.structure_manager as StructureManager
	var bush_spawn_count := randi_range(_BUSH_SPAWN_COUNT_MIN, _BUSH_SPAWN_COUNT_MAX)
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = _BUSH_NOISE_FREQUENCY
	var weighted_cells: Array[Dictionary] = []
	for cell_index in game.MAP_CELL_COUNT:
		if structure_manager.index_to_structures[cell_index]:
			continue
		var normalized_noise := (noise.get_noise_1d(float(cell_index)) + 1.0) * 0.5
		var weight: float = pow(normalized_noise, _BUSH_NOISE_CLUSTER_POWER)
		weighted_cells.append({"cell_index": cell_index, "weight": weight})
	var placed_count := mini(bush_spawn_count, weighted_cells.size())
	for _spawn_index in placed_count:
		var cell_index := _pick_weighted_cell_index(weighted_cells)
		var bush := StructureConfig.bush.instantiate() as Structure
		structure_manager.add_structure(bush, cell_index)


static func _pick_weighted_cell_index(weighted_cells: Array[Dictionary]) -> int:
	var total_weight := 0.0
	for entry in weighted_cells:
		total_weight += entry["weight"]
	var roll := randf() * total_weight
	var accumulated_weight := 0.0
	for entry_index in weighted_cells.size():
		var entry := weighted_cells[entry_index]
		accumulated_weight += entry["weight"]
		if roll <= accumulated_weight:
			var cell_index: int = entry["cell_index"]
			weighted_cells.remove_at(entry_index)
			return cell_index
	var last_entry: Dictionary = weighted_cells.pop_back()
	return last_entry["cell_index"] as int
