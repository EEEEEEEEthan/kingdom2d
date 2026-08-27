class_name OccupationId

enum TypeId {
	NONE = 0,
	LUMBERJACK = 1,
	SCAVENGER = 2,
}

static func get_display_name(occupation_id: TypeId) -> StringName:
	match occupation_id:
		TypeId.LUMBERJACK:
			return &"伐木工"
		TypeId.SCAVENGER:
			return &"拾荒者"
		_:
			return &""
