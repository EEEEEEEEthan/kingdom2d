extends Window

var _hut: GathererHut
var _rows: VBoxContainer


func _ready() -> void:
	visible = false
	close_requested.connect(hide)
	_rows = %Rows


func open_for(hut: GathererHut) -> void:
	_hut = hut
	_rebuild()
	_open_near_mouse()


func _process(_delta: float) -> void:
	if visible and _hut and is_instance_valid(_hut):
		_rebuild()


func _rebuild() -> void:
	if not _hut or not is_instance_valid(_hut):
		hide()
		return
	var signature := _signature()
	if _rows.has_meta("signature") and _rows.get_meta("signature") == signature:
		return
	_rows.set_meta("signature", signature)
	for child in _rows.get_children():
		child.queue_free()
	for slot in GathererHut.SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if slot < _hut.worker_ids.size():
			label.text = "居民 %s" % _hut.worker_ids[slot]
		else:
			label.text = "空位"
			var button := Button.new()
			button.text = "+"
			button.pressed.connect(_on_plus_pressed)
			row.add_child(label)
			row.add_child(button)
			_rows.add_child(row)
			continue
		row.add_child(label)
		_rows.add_child(row)


func _signature() -> String:
	var parts: PackedStringArray = []
	for worker_id in _hut.worker_ids:
		parts.append(str(worker_id))
	return "|".join(parts)


func _on_plus_pressed() -> void:
	if _hut and is_instance_valid(_hut):
		_hut.try_assign_unemployed()
		_rows.remove_meta("signature")
		_rebuild()


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
