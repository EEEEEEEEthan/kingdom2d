extends Control

signal character_open_requested(character: Character)

var _home: Structure
var _characters: CharacterManager
var _shown_ids: Array[int] = []


func bind(home: Structure, characters: CharacterManager) -> void:
	_home = home
	_characters = characters
	_sync()


func _process(_delta: float) -> void:
	if not is_inside_tree() or not get_window().visible:
		return
	if not _home or not is_instance_valid(_home):
		return
	_sync()


func alive() -> bool:
	return _home != null and is_instance_valid(_home)


func _sync() -> void:
	var ids := _resident_ids()
	if ids != _shown_ids:
		_rebuild(ids)
		return
	for child in %Residents.get_children():
		var character := _characters.characters.get(int(child.get_meta("character_id"))) as Character
		if character:
			(child as LinkButton).text = character.display_name()


func _resident_ids() -> Array[int]:
	var ids: Array[int] = []
	for character in _characters.characters.values():
		if character.home_cell_index == _home.cell_index:
			ids.append(character.id)
	ids.sort()
	return ids


func _rebuild(ids: Array[int]) -> void:
	while %Residents.get_child_count() > 0:
		var child := %Residents.get_child(0)
		%Residents.remove_child(child)
		child.free()
	_shown_ids = ids.duplicate()
	%EmptyLabel.visible = ids.is_empty()
	for character_id in ids:
		var character := _characters.characters.get(character_id) as Character
		var link := LinkButton.new()
		link.focus_mode = Control.FOCUS_NONE
		link.text = character.display_name() if character else ""
		link.set_meta("character_id", character_id)
		link.pressed.connect(_on_resident_pressed.bind(character_id))
		%Residents.add_child(link)


func _on_resident_pressed(character_id: int) -> void:
	var character := _characters.characters.get(character_id) as Character
	if character == null:
		return
	character_open_requested.emit(character)
