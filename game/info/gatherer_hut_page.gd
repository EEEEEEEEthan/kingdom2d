extends Control

var _hut: GathererHut
var _characters: CharacterManager
var _item_labels: Dictionary[int, Label] = {}


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
	if _hut:
		_sync()


func bind(hut: GathererHut, characters: CharacterManager) -> void:
	_hut = hut
	_characters = characters
	_sync()


func _process(_delta: float) -> void:
	if not is_inside_tree() or not get_window().visible:
		return
	if not _hut or not is_instance_valid(_hut):
		return
	_sync()


func alive() -> bool:
	return _hut != null and is_instance_valid(_hut)


func _sync() -> void:
	var slider := %PrioritySlider as HSlider
	if int(slider.value) != _hut.priority:
		slider.set_value_no_signal(_hut.priority)
	%PriorityLabel.text = GathererHut.PRIORITY_NAMES[_hut.priority]
	for slot in GathererHut.SLOT_COUNT:
		var label := get_node("%%Worker%d" % slot) as Label
		label.text = _worker_label(slot)
	var has_items := false
	for item_id in _item_labels:
		var count := _hut.container.count_of(item_id)
		(_item_labels[item_id].get_parent() as Control).visible = count > 0
		if count > 0:
			_item_labels[item_id].text = "×%d" % count
			has_items = true
	%ContainerEmpty.visible = not has_items


func _worker_label(slot: int) -> String:
	var game := Game.find(_hut)
	if game == null:
		return "空位"
	var workers := game.employment.workers_of(_hut.id)
	if slot >= workers.size():
		return "空位"
	var character: Character = _characters.characters.get(workers[slot])
	if character == null:
		return "空位"
	return character.display_name()


func _on_priority_slider(value: float) -> void:
	if not _hut or not is_instance_valid(_hut):
		return
	_hut.change_priority(int(value))
	_sync()
