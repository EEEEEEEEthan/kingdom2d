@tool
extends TileMapLayer
class_name Terrain

enum TerrainType {
	Land,
	Water,
}

const TERRAIN_SET := 0
const GROUND_ROW_Y := -1

var _sprites: Array[Sprite2D]:
	get:
		if not _sprites:
			_sprites = [
				%Sprite2D0,
				%Sprite2D1,
				%Sprite2D2,
				%Sprite2D3,
				%Sprite2D4,
			]
		return _sprites

@export_range(0, 1) var view_height: float = 1:
	set(value):
		view_height = clamp(value, 0, 1)
		if not is_node_ready():
			await ready
		var cnt = len(_sprites)
		for i in cnt:
			var y = remap(value, 0, 1, (cnt - i) * 32, 0)
			var sprite := _sprites[i]
			var pos = sprite.position
			pos.y = y
			_sprites[i].position = pos

func fill_terrain(type: TerrainType) -> void:
	var terrain_index: int
	match type:
		TerrainType.Land:
			terrain_index = 1
		TerrainType.Water:
			terrain_index = 0
	var cells: Array[Vector2i] = []
	cells.resize(Game.MAP_CELL_COUNT)
	for x: int in Game.MAP_CELL_COUNT:
		cells[x] = Vector2i(x, GROUND_ROW_Y)
	set_cells_terrain_connect(cells, TERRAIN_SET, terrain_index)
	update_internals()

func set_terrain(index: int, type: TerrainType) -> void:
	var terrain_index: int
	match type:
		TerrainType.Land:
			terrain_index = 1
		TerrainType.Water:
			terrain_index = 0
	var coord := Vector2i(index, GROUND_ROW_Y)
	set_cells_terrain_connect(
		[coord, coord + Vector2i(-1, 0), coord + Vector2i(1, 0)],
		TERRAIN_SET,
		terrain_index,
	)
	update_internals()
