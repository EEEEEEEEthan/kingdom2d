extends RefCounted
class_name ItemConfig

## 所有物品 icon 共用一个横向 atlas，每格边长 CELL_SIZE，物品按 _atlas_index 取格。

const CELL_SIZE := 10
const ATLAS_PATH := &"res://game/items/item_atlas.tres"

enum TypeId {
	NONE = 0,
	BERRY = 1,
}

static var berry: ItemConfig:
	get:
		if not berry:
			berry = ItemConfig.new()
			berry.id = TypeId.BERRY
			berry.name = &"浆果"
			berry._atlas_index = 0
		return berry

static var configs_by_id: Dictionary[TypeId, ItemConfig] = {
	berry.id: berry,
}

var id: TypeId = TypeId.NONE
var name: StringName
var _atlas_index := 0
var _icon: AtlasTexture

var icon: Texture2D:
	get:
		if not _icon:
			_icon = AtlasTexture.new()
			_icon.atlas = ResourceLoader.load(ATLAS_PATH)
			_icon.region = Rect2(_atlas_index * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE)
		return _icon
