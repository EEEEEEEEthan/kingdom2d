extends VBoxContainer

var _structure: Structure
var _rows: Dictionary[int, Control] = {}
var _revision := ""


func _ready() -> void:
	if _structure:
		_sync()


func bind(structure: Structure) -> void:
	_structure = structure
	_sync()


func _process(_delta: float) -> void:
	if not is_inside_tree() or not get_window().visible:
		return
	if not _structure or not is_instance_valid(_structure):
		return
	if _revision_key() == _revision:
		return
	_sync()


func _sync() -> void:
	if not is_node_ready():
		return
	%Title.text = _title()
	var shown := 0
	for item_id in ItemConfig.configs_by_id:
		var count := _structure.container.count_of(item_id)
		var row := _row(item_id)
		var visible_row := count > 0 or _structure is Warehouse
		row.visible = visible_row
		if not visible_row:
			continue
		shown += 1
		(row.get_node("Count") as Label).text = "×%d" % count
		if _structure is Warehouse:
			var menu := row.get_node("Policy") as OptionButton
			var policy := (_structure as Warehouse).policy_of(item_id)
			if menu.selected != policy:
				menu.select(policy)
	%Empty.visible = shown == 0
	_revision = _revision_key()


func _title() -> String:
	if _structure is GathererHut:
		return "容器 %d/%d" % [_structure.berry_count(), GathererHut.BERRY_CAPACITY]
	if _structure is LumberCamp:
		return "容器 %d/%d" % [(_structure as LumberCamp).log_count(), LumberCamp.LOG_CAPACITY]
	if Food.is_dwelling(_structure):
		return "库存 %d/%d" % [Food.stored(_structure), Food.HOME_CAPACITY]
	return "库存"


func _row(item_id: int) -> Control:
	if _rows.has(item_id):
		return _rows[item_id]
	var config := ItemConfig.configs_by_id[item_id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = config.icon
	icon.custom_minimum_size = config.icon.get_size()
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	row.add_child(icon)
	var label := Label.new()
	label.name = "Count"
	row.add_child(label)
	if _structure is Warehouse:
		var menu := OptionButton.new()
		menu.name = "Policy"
		menu.focus_mode = Control.FOCUS_NONE
		for policy in Warehouse.POLICY_NAMES.size():
			menu.add_item(Warehouse.POLICY_NAMES[policy], policy)
		var warehouse := _structure as Warehouse
		menu.item_selected.connect(func(index: int) -> void: warehouse.set_storage_policy(item_id, index))
		row.add_child(menu)
	%Items.add_child(row)
	_rows[item_id] = row
	return row


func _revision_key() -> String:
	var parts: PackedStringArray = []
	for item_id in ItemConfig.configs_by_id:
		var count := _structure.container.count_of(item_id)
		var policy := 0
		if _structure is Warehouse:
			policy = (_structure as Warehouse).policy_of(item_id)
		if count > 0 or _structure is Warehouse:
			parts.append("%d:%d:%d" % [item_id, count, policy])
	return "|".join(parts)
