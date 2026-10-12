extends RefCounted
class_name GameBuilder

const _OAK_SPAWN_COUNT_MIN = 24
const _OAK_SPAWN_COUNT_MAX = 96
const _BUSH_SPAWN_COUNT_MIN = 48
const _BUSH_SPAWN_COUNT_MAX = 160
const _BUSH_NOISE_FREQUENCY = 0.012
const _BUSH_NOISE_CLUSTER_POWER = 4.0
static func build(game) -> void:
	game.terrain.fill_terrain(Terrain.TerrainType.Land)
	_spawn_sovereign_banner(game)
	_spawn_starting_depot(game)
	_spawn_random_oaks(game)
	_spawn_clustered_bushes(game)


static func _map_center_cell_index() -> int:
	return Game.MAP_CELL_COUNT / 2


static func _spawn_sovereign_banner(game) -> void:
	var structure_manager := game.structure_manager as StructureManager
	var banner := StructureConfig.sovereign_banner.instantiate() as Structure
	structure_manager.add_structure(banner, _map_center_cell_index())


static func _spawn_starting_depot(game) -> void:
	var structure_manager := game.structure_manager as StructureManager
	var center := _map_center_cell_index()
	var warehouse := StructureConfig.warehouse.instantiate() as Warehouse
	structure_manager.add_structure(warehouse, center - 1)
	var home := StructureConfig.sunken_floor_thatch_hovel.instantiate() as Structure
	structure_manager.add_structure(home, center + 1)
	var resident: Character = game.spawn_resident_at_cell(center + 1)
	warehouse.assign_manager(resident)


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
