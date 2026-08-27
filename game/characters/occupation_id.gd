class_name OccupationId

enum TypeId {
	NONE = 0,
	LUMBERJACK = 1,
	SCAVENGER = 2,
}

static var _tokens: Dictionary = {}


static func get_display_name(occupation_id: TypeId) -> StringName:
	match occupation_id:
		TypeId.LUMBERJACK:
			return &"伐木工"
		TypeId.SCAVENGER:
			return &"拾荒者"
		_:
			return &""


static func get_description(occupation_id: TypeId) -> String:
	match occupation_id:
		TypeId.LUMBERJACK:
			return "工作时段寻找橡树并砍伐，收获原木。"
		TypeId.SCAVENGER:
			return "工作时段寻找灌木并采集，收获浆果。"
		_:
			return ""


static func get_related(occupation_id: TypeId) -> Array[TypeId]:
	var related: Array[TypeId] = []
	match occupation_id:
		TypeId.LUMBERJACK:
			related.append(TypeId.SCAVENGER)
		TypeId.SCAVENGER:
			related.append(TypeId.LUMBERJACK)
	return related


static func get_bbcode(occupation_id: TypeId) -> String:
	if occupation_id == TypeId.NONE:
		return String(get_display_name(occupation_id))
	_ensure_tokens()
	var token: HoverInfoToken = _tokens.get(occupation_id)
	if token == null:
		return String(get_display_name(occupation_id))
	return token.get_bbcode(String(get_display_name(occupation_id)))


static func _ensure_tokens() -> void:
	if not _tokens.is_empty():
		return
	_tokens[TypeId.LUMBERJACK] = HoverInfoDispatcher.register_hover_info(
			func() -> Control: return _make_hover(TypeId.LUMBERJACK)
	)
	_tokens[TypeId.SCAVENGER] = HoverInfoDispatcher.register_hover_info(
			func() -> Control: return _make_hover(TypeId.SCAVENGER)
	)


static func _make_hover(occupation_id: TypeId) -> Control:
	var related_names: PackedStringArray = []
	for related_id in get_related(occupation_id):
		related_names.append(get_bbcode(related_id))
	var content := "%s\n相关职业： %s" % [
			get_description(occupation_id),
			", ".join(related_names),
	]
	return HoverInfoDispatcher.create_simple(String(get_display_name(occupation_id)), content)
