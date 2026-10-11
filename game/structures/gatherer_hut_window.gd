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
	var priority_label := Label.new()
	priority_label.text = GathererHut.PRIORITY_NAMES[_hut.priority]
	_rows.add_child(priority_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = GathererHut.Priority.NORMAL
	slider.step = 1
	slider.tick_count = GathererHut.PRIORITY_NAMES.size()
	slider.ticks_on_borders = true
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 16)
	# 左端是普通，右端是非常优先。
	slider.set_value_no_signal(GathererHut.Priority.NORMAL - _hut.priority)
	slider.value_changed.connect(_on_priority_slider)
	_rows.add_child(slider)
	for slot in GathererHut.SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if slot < _hut.worker_ids.size():
			label.text = "居民 %s" % _hut.worker_ids[slot]
		else:
			label.text = "空位"
		row.add_child(label)
		_rows.add_child(row)


func _signature() -> String:
	var parts: PackedStringArray = [str(_hut.priority)]
	for worker_id in _hut.worker_ids:
		parts.append(str(worker_id))
	return "|".join(parts)


func _on_priority_slider(value: float) -> void:
	if not _hut or not is_instance_valid(_hut):
		return
	_hut.change_priority(GathererHut.Priority.NORMAL - int(value))
	if _rows.has_meta("signature"):
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
	# 原生窗口在 show() 里才创建，视口还挂在无效窗口上，首帧是透明的。
	# 再走一次内容缩放会把视口接到已经映射的窗口，不用改窗口尺寸。
	content_scale_factor = content_scale_factor
