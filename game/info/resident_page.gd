extends Control

var _character: Character


func bind(character: Character) -> void:
	_character = character
	_sync()


func _process(_delta: float) -> void:
	if not is_inside_tree() or not get_window().visible:
		return
	if not _character or not is_instance_valid(_character):
		return
	_sync()


func alive() -> bool:
	return _character != null and is_instance_valid(_character)


func _sync() -> void:
	var avatar := %Avatar as PixelAvatar
	avatar.apply_id(_character.id)
	var job := _character.occupation_name()
	if job.is_empty():
		%IdentityLabel.text = _character.display_name()
	else:
		%IdentityLabel.text = "%s，%s" % [_character.display_name(), job]
	%ActivityLabel.text = _character.current_activity()
