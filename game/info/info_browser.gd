extends Window

signal reset_game_requested

const SETTINGS_PAGE := preload("res://game/info/settings_page.tscn")
const RESIDENT_PAGE := preload("res://game/info/resident_page.tscn")
const GATHERER_HUT_PAGE := preload("res://game/info/gatherer_hut_page.tscn")

var _history: Array[String] = []
var _index := -1


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
		child.free()
	var page := _make_page(path)
	if page:
		%PageHost.add_child(page)
		if page.has_signal("reset_game_requested"):
			page.reset_game_requested.connect(reset_game_requested.emit)
	_sync_nav_buttons()
	show()


func _make_page(path: String) -> Control:
	var parts := path.split("/")
	match parts[0]:
		"settings":
			title = "设置"
			return SETTINGS_PAGE.instantiate()
		"resident":
			var character := _character_by_id(int(parts[1]))
			if not character:
				return null
			title = character.display_name()
			var page := RESIDENT_PAGE.instantiate()
			page.bind(character)
			return page
		"structure":
			var structure := _structure_by_id(int(parts[1]))
			if structure is GathererHut:
				title = "采集者小屋"
				var page := GATHERER_HUT_PAGE.instantiate()
				page.bind(structure)
				return page
	title = "Kingdom2D"
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


func _structure_by_id(structure_id: int) -> Structure:
	var game := _find_game()
	if not game:
		return null
	return game.structure_manager.get_structure_by_id(structure_id)


func _find_game() -> Game:
	var tree := get_tree()
	if not tree:
		return null
	return _find_game_in(tree.root)


func _find_game_in(node: Node) -> Game:
	if node is Game:
		return node
	for child in node.get_children():
		var found := _find_game_in(child)
		if found:
			return found
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
