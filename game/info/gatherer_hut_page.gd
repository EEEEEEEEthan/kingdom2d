extends Control

var _hut: GathererHut
var _characters: CharacterManager


func _ready() -> void:
	%PrioritySlider.value_changed.connect(_on_priority_slider)


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


func _worker_label(slot: int) -> String:
	if slot >= _hut.worker_ids.size():
		return "空位"
	var character: Character = _characters.characters.get(_hut.worker_ids[slot])
	if character == null:
		return "空位"
	return character.display_name()


func _on_priority_slider(value: float) -> void:
	if not _hut or not is_instance_valid(_hut):
		return
	_hut.change_priority(int(value))
	_sync()
