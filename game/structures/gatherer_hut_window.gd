extends Window

var _hut: GathererHut


func _ready() -> void:
	visible = false
	close_requested.connect(hide)
	%PrioritySlider.value_changed.connect(_on_priority_slider)


func open_for(hut: GathererHut) -> void:
	_hut = hut
	_sync()
	_open_near_mouse()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not _hut or not is_instance_valid(_hut):
		hide()
		return
	_sync()


func _sync() -> void:
	var slider := %PrioritySlider as HSlider
	if int(slider.value) != _hut.priority:
		slider.set_value_no_signal(_hut.priority)
	%PriorityLabel.text = GathererHut.PRIORITY_NAMES[_hut.priority]
	for slot in GathererHut.SLOT_COUNT:
		var label := get_node("%Worker%d" % slot) as Label
		if slot < _hut.worker_ids.size():
			label.text = "居民 %s" % _hut.worker_ids[slot]
		else:
			label.text = "空位"


func _on_priority_slider(value: float) -> void:
	if not _hut or not is_instance_valid(_hut):
		return
	_hut.change_priority(int(value))
	_sync()


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
