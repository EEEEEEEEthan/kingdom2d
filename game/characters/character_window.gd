extends Window

var _character: Character


func _ready() -> void:
	visible = false
	close_requested.connect(hide)


func open_for(character: Character) -> void:
	_character = character
	_sync()
	_open_near_mouse()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not _character or not is_instance_valid(_character):
		hide()
		return
	_sync()


func _sync() -> void:
	title = _character.display_name()
	%NameLabel.text = "姓名：%s" % _character.display_name()
	%JobLabel.text = "职业：%s" % _character.occupation_name()
	%ActivityLabel.text = "正在：%s" % _character.current_activity()


func _open_near_mouse() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	position = pos
	show()
	mode = MODE_WINDOWED
	grab_focus()
	content_scale_factor = content_scale_factor
