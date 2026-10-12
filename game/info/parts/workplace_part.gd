extends VBoxContainer

signal character_open_requested(character: Character)

var _structure: Structure
var _characters: CharacterManager
var _revision := ""


func _ready() -> void:
	%PrioritySlider.value_changed.connect(_on_priority_slider)
	for slot in _row_count():
		var link := get_node("%%Worker%d" % slot) as LinkButton
		link.pressed.connect(_on_worker_pressed.bind(slot))
	if _structure:
		_sync()


func bind(structure: Structure, characters: CharacterManager) -> void:
	_structure = structure
	_characters = characters
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
	var slider := %PrioritySlider as HSlider
	var priority := int(_structure.get("priority"))
	if int(slider.value) != priority:
		slider.set_value_no_signal(priority)
	%PriorityLabel.text = GathererHut.PRIORITY_NAMES[priority]
	for slot in _row_count():
		var row := get_node("WorkerRow%d" % slot) as Control
		row.visible = slot < _slot_count()
		if row.visible:
			_sync_worker(slot)
	_revision = _revision_key()


func _revision_key() -> String:
	var parts: PackedStringArray = [str(_structure.get("priority"))]
	var game := Game.find(_structure)
	if game:
		for worker_id in game.employment.workers_of(_structure.id):
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


func _slot_count() -> int:
	if _structure is GathererHut:
		return GathererHut.SLOT_COUNT
	if _structure is LumberCamp:
		return LumberCamp.SLOT_COUNT
	if _structure is Warehouse:
		return Warehouse.SLOT_COUNT
	return 0


func _row_count() -> int:
	return maxi(GathererHut.SLOT_COUNT, maxi(LumberCamp.SLOT_COUNT, Warehouse.SLOT_COUNT))


func _worker(slot: int) -> Character:
	var game := Game.find(_structure)
	if game == null:
		return null
	var workers := game.employment.workers_of(_structure.id)
	if slot >= workers.size():
		return null
	return _characters.characters.get(workers[slot]) as Character


func _on_worker_pressed(slot: int) -> void:
	var character := _worker(slot)
	if character == null:
		return
	character_open_requested.emit(character)


func _on_priority_slider(value: float) -> void:
	if not _structure or not is_instance_valid(_structure):
		return
	_structure.call("change_priority", int(value))
	_sync()
