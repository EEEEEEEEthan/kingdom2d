extends Window

signal reset_game_requested

const SETTINGS_PAGE := preload("res://game/info/settings_page.tscn")
const RESIDENT_PAGE := preload("res://game/info/resident_page.tscn")
const GATHERER_HUT_PAGE := preload("res://game/info/gatherer_hut_page.tscn")
const HOME_PAGE := preload("res://game/info/home_page.tscn")

var _history: Array[String] = []
var _index := -1
var _game: Game


func _ready() -> void:
	visible = false
	close_requested.connect(hide)
	%BackButton.pressed.connect(go_back)
	%ForwardButton.pressed.connect(go_forward)


func open_settings() -> void:
	_open("settings")


func open_resident(character: Character) -> void:
	_open("resident/%d" % character.id)


func open_structure(hut: GathererHut) -> void:
	_open("structure/%d" % hut.id)


func open_home(home: Structure) -> void:
	_open("home/%d" % home.id)


func go_back() -> void:
	if _index <= 0:
		return
	_index -= 1
	_show_current()


func go_forward() -> void:
	if _index >= _history.size() - 1:
		return
	_index += 1
	_show_current()


func current_path() -> String:
	if _index < 0:
		return ""
	return _history[_index]


func _open(path: String) -> void:
	var was_visible := visible
	if _index < 0 or _history[_index] != path:
		_history.resize(_index + 1)
		_history.append(path)
		_index = _history.size() - 1
	_show_current()
	if not was_visible:
		_open_near_mouse()
	else:
		show()
		grab_focus()


func _process(_delta: float) -> void:
	if not visible:
		return
	var page := _current_page()
	if page and page.has_method("alive") and not page.alive():
		hide()


func _show_current() -> void:
	var path := current_path()
	%PathLabel.text = path
	for child in %PageHost.get_children():
		%PageHost.remove_child(child)
		child.queue_free()
	var page := _make_page(path)
	if page:
		%PageHost.add_child(page)
		if page.has_signal("reset_game_requested"):
			page.reset_game_requested.connect(reset_game_requested.emit)
		if page.has_signal("character_open_requested"):
			page.character_open_requested.connect(open_resident)
	_sync_nav_buttons()
	show()


func _make_page(path: String) -> Control:
	var parts := path.split("/")
	match parts[0]:
		"settings":
			return SETTINGS_PAGE.instantiate()
		"resident":
			var character := _character_by_id(int(parts[1]))
			if not character:
				return null
			var page := RESIDENT_PAGE.instantiate()
			page.bind(character)
			return page
		"structure":
			var game := _find_game()
			if not game:
				return null
			var structure := game.structure_manager.get_structure_by_id(int(parts[1]))
			if structure is GathererHut:
				var page := GATHERER_HUT_PAGE.instantiate()
				page.bind(structure, game.character_manager)
				return page
		"home":
			var game := _find_game()
			if not game:
				return null
			var home := game.structure_manager.get_structure_by_id(int(parts[1]))
			if home == null:
				return null
			var page := HOME_PAGE.instantiate()
			page.bind(home, game.character_manager)
			return page
	return null


func _current_page() -> Control:
	if %PageHost.get_child_count() == 0:
		return null
	return %PageHost.get_child(0) as Control


func _sync_nav_buttons() -> void:
	%BackButton.disabled = _index <= 0
	%ForwardButton.disabled = _index >= _history.size() - 1


func _character_by_id(character_id: int) -> Character:
	var game := _find_game()
	if not game:
		return null
	return game.character_manager.characters.get(character_id) as Character


func _find_game() -> Game:
	if is_instance_valid(_game):
		return _game
	_game = Game.find(self)
	if _game:
		return _game
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is Game:
			_game = child
			return _game
		if child is Window:
			var named := child.get_node_or_null("%Game")
			if named is Game:
				_game = named
				return _game
	return null


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
