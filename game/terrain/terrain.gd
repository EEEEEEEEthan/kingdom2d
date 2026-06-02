extends TileMapLayer
class_name Terrain

enum TerrainType {
	Land,
	Water,
}

const TERRAIN_SET := 0

func set_terrain(index: int, type: TerrainType) -> void:
	var terrain_index: int
	match type:
		TerrainType.Land:
			terrain_index = 1
		TerrainType.Water:
			terrain_index = 0
	set_cells_terrain_connect([Vector2i(index, 0)], TERRAIN_SET, terrain_index)
