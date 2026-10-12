extends Control

var _warehouse: Warehouse
var _item_labels: Dictionary[int, Label] = {}
var _revision := ""


func _ready() -> void:
	%PrioritySlider.value_changed.connect(_on_priority_slider)
	for item_id in ItemConfig.configs_by_id:
		var config := ItemConfig.configs_by_id[item_id]
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = config.icon
		icon.custom_minimum_size = config.icon.get_size()
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		row.add_child(icon)
		var label := Label.new()
		row.add_child(label)
		%Items.add_child(row)
		_item_labels[item_id] = label
	if _warehouse:
		_sync()


func bind(warehouse: Warehouse) -> void:
	_warehouse = warehouse
	_sync()


func _process(_delta: float) -> void:
	if not is_inside_tree() or not get_window().visible:
		return
	if not _warehouse or not is_instance_valid(_warehouse):
		return
	if _revision_key() == _revision:
		return
	_sync()


func alive() -> bool:
	return _warehouse != null and is_instance_valid(_warehouse)


func _sync() -> void:
	if not _warehouse or not is_node_ready():
		return
	var slider := %PrioritySlider as HSlider
	if int(slider.value) != _warehouse.priority:
		slider.set_value_no_signal(_warehouse.priority)
	%PriorityLabel.text = Warehouse.PRIORITY_NAMES[_warehouse.priority]
	var has_items := false
	for item_id in _item_labels:
		var count := _warehouse.container.count_of(item_id)
		(_item_labels[item_id].get_parent() as Control).visible = count > 0
		if count > 0:
			_item_labels[item_id].text = "×%d" % count
			has_items = true
	%ContainerEmpty.visible = not has_items
	_revision = _revision_key()


func _revision_key() -> String:
	var parts: PackedStringArray = [str(_warehouse.priority)]
	for item_id in _item_labels:
		var count := _warehouse.container.count_of(item_id)
		if count > 0:
			parts.append("%d:%d" % [item_id, count])
	return "|".join(parts)


func _on_priority_slider(value: float) -> void:
	if not _warehouse or not is_instance_valid(_warehouse):
		return
	_warehouse.change_priority(int(value))
	_sync()
