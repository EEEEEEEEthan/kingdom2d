extends PopupPanel

signal reset_game_requested


func _ready() -> void:
	visible = false
	borderless = true
	always_on_top = false
	transparent = false
	unfocusable = true
	visibility_changed.connect(_on_visibility_changed)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.561, 0.337, 0.231, 1)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	var bar := HBoxContainer.new()
	bar.name = "TitleBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var title_label := Label.new()
	title_label.text = "Kingdom2D"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.pressed.connect(hide)
	bar.add_child(close_button)
	bar.gui_input.connect(_on_title_gui_input)
	bar.z_index = 100
	bar.top_level = true
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(bar)


func open_near_mouse() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	always_on_top = false
	transient = false
	popup(Rect2i(pos, size))
	_fit_client()
	_raise_above_game()


func _process(_delta: float) -> void:
	if not visible:
		return
	var bar := get_node_or_null("TitleBar") as Control
	if bar:
		var logical := Vector2(size) / content_scale_factor
		bar.position = Vector2(4, 2)
		bar.size = Vector2(logical.x - 8, 18)
	var body := get_node_or_null("VBoxContainer") as Control
	if body:
		body.offset_top = 40


func _fit_client() -> void:
	var body := get_node_or_null("VBoxContainer") as Control
	if body:
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		body.offset_left = 8
		body.offset_top = 36
		body.offset_right = -8
		body.offset_bottom = -8


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed:
		_drag_window()


func _drag_window() -> void:
	var offset := DisplayServer.mouse_get_position() - Vector2i(position)
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		position = DisplayServer.mouse_get_position() - offset
		await get_tree().process_frame


func _game_window() -> Window:
	var parent_node := get_parent()
	if parent_node == null:
		return null
	return parent_node.get_node_or_null("GameWindow") as Window


func _raise_above_game() -> void:
	var game_window := _game_window()
	if game_window:
		game_window.always_on_top = false
		game_window.unfocusable = false
		game_window.hide()
		await get_tree().process_frame
		game_window.show()
	transient = false
	unfocusable = true
	var id := get_window_id()
	await get_tree().process_frame
	always_on_top = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, id)
	for _i in 4:
		DisplayServer.window_move_to_foreground(id)
		await get_tree().process_frame


func _on_visibility_changed() -> void:
	if not visible:
		_restore_game_top()


func _restore_game_top() -> void:
	var structure := get_parent().get_node_or_null("StructureWindow") as Window
	if structure and structure.visible:
		return
	var game_window := _game_window()
	if game_window:
		game_window.unfocusable = true
		game_window.always_on_top = true
