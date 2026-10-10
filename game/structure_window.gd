extends PopupPanel

var _game: Game
var _structure_id := 0
var _people_signature := ""
var _info: Label
var _upgrade: Button
var _people: VBoxContainer


func _ready() -> void:
	visible = false
	borderless = true
	always_on_top = false
	transparent = false
	unfocusable = true
	visibility_changed.connect(_on_visibility_changed)
	_info = %Info
	_upgrade = %Upgrade
	_people = %People
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.561, 0.337, 0.231, 1)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	var bar := HBoxContainer.new()
	bar.name = "TitleBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text = "建筑"
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


func open_for(game: Game, structure_id: int) -> void:
	_game = game
	_structure_id = structure_id
	_people_signature = ""
	open_near_mouse()
	_refresh()


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
	var margin := get_node_or_null("Margin") as Control
	if margin:
		margin.offset_top = 40
	_refresh()


func _structure() -> Structure:
	if _game == null:
		return null
	return _game.structure_manager.get_structure_by_id(_structure_id)


func _refresh() -> void:
	var structure := _structure()
	if structure == null:
		hide()
		return
	title = structure.config.name
	var title_label := get_node_or_null("TitleBar/TitleLabel") as Label
	if title_label:
		title_label.text = structure.config.name
	_info.text = structure.inspect_text() if structure is LoopStructure else structure.config.name
	var loop := structure as LoopStructure
	_upgrade.visible = loop != null and (loop.kind == LoopStructure.Kind.WAREHOUSE or loop.kind == LoopStructure.Kind.LUMBER)
	if _upgrade.visible:
		_upgrade.text = "升级（%d 原木）" % LoopStructure.WAREHOUSE_UPGRADE_COST
		_upgrade.disabled = loop.logs < LoopStructure.WAREHOUSE_UPGRADE_COST
	_rebuild_people(loop)


func _rebuild_people(loop: LoopStructure) -> void:
	var box := _people
	if loop == null:
		if _people_signature != "":
			_people_signature = ""
			for child in box.get_children():
				child.free()
		return
	var signature := _people_signature_for(loop)
	if signature == _people_signature:
		return
	_people_signature = signature
	for child in box.get_children():
		child.free()
	if loop.kind == LoopStructure.Kind.TENT or loop.kind == LoopStructure.Kind.HUT:
		for character in _game.character_manager.characters.values():
			if character.home_id == loop.id:
				var label := Label.new()
				label.text = "居民 %d" % character.id
				box.add_child(label)
		return
	if loop.kind != LoopStructure.Kind.LUMBER and loop.kind != LoopStructure.Kind.GUILD:
		return
	var occupied := _worker_count(loop.id) > 0 and loop.kind == LoopStructure.Kind.LUMBER
	for character in _game.character_manager.characters.values():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "居民 %d %s" % [character.id, _duty_name(character)]
		row.add_child(label)
		if character.workplace_id == loop.id:
			var clear_button := Button.new()
			clear_button.text = "撤下"
			clear_button.pressed.connect(character.clear_duty)
			row.add_child(clear_button)
		elif character.home_id != 0 and character.duty == Character.Duty.NONE and not occupied:
			var assign_button := Button.new()
			assign_button.text = "招募" if loop.kind == LoopStructure.Kind.GUILD else "安排"
			var resident: Character = character
			var duty := Character.Duty.BUILDER if loop.kind == LoopStructure.Kind.GUILD else Character.Duty.LUMBER
			assign_button.pressed.connect(func() -> void: resident.assign_duty(duty, loop.id))
			row.add_child(assign_button)
		box.add_child(row)


func _people_signature_for(loop: LoopStructure) -> String:
	var parts: PackedStringArray = []
	for character in _game.character_manager.characters.values():
		parts.append("%d:%d:%d:%d" % [character.id, character.home_id, character.duty, character.workplace_id])
	parts.append(str(loop.id))
	parts.append(str(loop.kind))
	return "|".join(parts)


func _worker_count(workplace_id: int) -> int:
	var count := 0
	for character in _game.character_manager.characters.values():
		if character.workplace_id == workplace_id:
			count += 1
	return count


func _duty_name(character: Character) -> String:
	match character.duty:
		Character.Duty.LUMBER:
			return "伐木"
		Character.Duty.BUILDER:
			return "建筑工"
	return "空闲"


func _fit_client() -> void:
	var margin := get_node_or_null("Margin") as Control
	if margin:
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.offset_left = 8
		margin.offset_top = 36
		margin.offset_right = -8
		margin.offset_bottom = -8


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
	var settings := get_parent().get_node_or_null("ControlWindow") as Window
	if settings and settings.visible:
		return
	var game_window := _game_window()
	if game_window:
		game_window.unfocusable = true
		game_window.always_on_top = true


func _on_upgrade_pressed() -> void:
	var loop := _structure() as LoopStructure
	if loop == null or (loop.kind != LoopStructure.Kind.WAREHOUSE and loop.kind != LoopStructure.Kind.LUMBER):
		return
	if loop.logs < LoopStructure.WAREHOUSE_UPGRADE_COST:
		return
	loop.logs -= LoopStructure.WAREHOUSE_UPGRADE_COST
	loop.level += 1
