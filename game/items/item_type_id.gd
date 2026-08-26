class_name ItemTypeId

enum TypeId {
	NONE = 0,
	IRON_COIN = 1,
	LOG = 2,
	BERRY = 3,
}

static func get_display_name(item_id: TypeId) -> StringName:
	match item_id:
		TypeId.IRON_COIN:
			return &"铁币"
		TypeId.LOG:
			return &"原木"
		TypeId.BERRY:
			return &"浆果"
		_:
			return &""
