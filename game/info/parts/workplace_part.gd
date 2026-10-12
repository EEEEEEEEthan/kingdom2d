extends VBoxContainer

signal character_open_requested(character: Character)

var _hut: GathererHut
var _characters: CharacterManager
var _revision := ""


func _ready() -> void:
	%PrioritySlider.value_changed.connect(_on_priority_slider)
	for slot in GathererHut.SLOT_COUNT:
		var link := get_node("%%Worker%d" % slot) as LinkButton
		link.pressed.connect(_on_worker_pressed.bind(slot))
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
	if _revision_key() == _revision:
		return
	_sync()


func _sync() -> void:
	if not is_node_ready():
		return
	var slider := %PrioritySlider as HSlider
	if int(slider.value) != _hut.priority:
		slider.set_value_no_signal(_hut.priority)
	%PriorityLabel.text = GathererHut.PRIORITY_NAMES[_hut.priority]
	for slot in GathererHut.SLOT_COUNT:
		_sync_worker(slot)
	_revision = _revision_key()


func _revision_key() -> String:
	var parts: PackedStringArray = [str(_hut.priority)]
	var game := Game.find(_hut)
	if game:
		for worker_id in game.employment.workers_of(_hut.id):
			parts.append(str(worker_id))
	return "|".join(parts)


func _sync_worker(slot: int) -> void:
	var link := get_node("%%Worker%d" % slot) as LinkButton
	var character := _worker(slot)
	var avatar := get_node("%%WorkerAvatar%d" % slot) as PixelAvatar
	if character == null:
		avatar.visible = false
		link.text = "空位"
		link.disabled = true
		link.remove_meta("character_id")
		return
	avatar.visible = true
	avatar.apply_id(character.id)
	link.text = character.display_name()
	link.disabled = false
	link.set_meta("character_id", character.id)


func _worker(slot: int) -> Character:
	var game := Game.find(_hut)
	if game == null:
		return null
	var workers := game.employment.workers_of(_hut.id)
	if slot >= workers.size():
		return null
	return _characters.characters.get(workers[slot]) as Character


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
