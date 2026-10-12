extends Control

signal character_open_requested(character: Character)

var _hut: GathererHut
var _characters: CharacterManager
var _item_labels: Dictionary[int, Label] = {}


func _ready() -> void:
	%PrioritySlider.value_changed.connect(_on_priority_slider)
	for slot in GathererHut.SLOT_COUNT:
		var link := get_node("%%Worker%d" % slot) as LinkButton
		link.pressed.connect(_on_worker_pressed.bind(slot))
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
	%ContainerTitle.text = "容器 %d/%d" % [_hut.berry_count(), GathererHut.BERRY_CAPACITY]
	for slot in GathererHut.SLOT_COUNT:
		_sync_worker(slot)
	var has_items := false
	for item_id in _item_labels:
		var count := _hut.container.count_of(item_id)
		(_item_labels[item_id].get_parent() as Control).visible = count > 0
		if count > 0:
			_item_labels[item_id].text = "×%d" % count
			has_items = true
	%ContainerEmpty.visible = not has_items


func _sync_worker(slot: int) -> void:
	var link := get_node("%%Worker%d" % slot) as LinkButton
	var character := _worker(slot)
	if character == null:
		link.text = "空位"
		link.disabled = true
		link.remove_meta("character_id")
		return
	link.text = character.display_name()
	link.disabled = false
	link.set_meta("character_id", character.id)


func _worker(slot: int) -> Character:
	if slot >= _hut.worker_ids.size():
		return null
	return _characters.characters.get(_hut.worker_ids[slot]) as Character


func _on_worker_pressed(slot: int) -> void:
	var character := _worker(slot)
	if character == null:
		return
	character_open_requested.emit(character)


func _on_priority_slider(value: float) -> void:
	if not _hut or not is_instance_valid(_hut):
		return
	_hut.change_priority(int(value))
	_sync()
