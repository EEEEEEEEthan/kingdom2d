@tool
extends Control
class_name SideTabStrip

var _buttons: Array[SideTab] = []
var _visual_y: PackedFloat32Array = PackedFloat32Array()
var _velocity: PackedFloat32Array = PackedFloat32Array()
var _dragging := false
var _drag_from := -1
var _drag_grab := 0.0
var _drag_y := 0.0
var _drop_idx := -1
var _press_idx := -1
var _press_local := Vector2.ZERO
var _last_step_usec := 0


func is_dragging() -> bool:
	return _dragging


func _ready() -> void:
	refresh()


func refresh() -> void:
	var count := _tab_count()
	while _buttons.size() > count:
		_buttons.pop_back().queue_free()
	while _buttons.size() < count:
		_add_tab_button()
	var old := _visual_y.size()
	_visual_y.resize(count)
	_velocity.resize(count)
	for i in count:
		if i >= old:
			_visual_y[i] = _slot_y(i, -1, -1)
			_velocity[i] = 0.0
		_buttons[i].set_tab_title(_tabs().get_tab_title(i))
		_buttons[i].set_selected(i == _tabs().current_tab)
		_buttons[i].set_dragging(_dragging)
	set_process(true)
	update_minimum_size()
	_layout_tabs()


func _add_tab_button() -> void:
	var tab: SideTab = %SideTabPlaceHolder.create_instance() as SideTab
	tab.button_down.connect(_on_tab_button_down.bind(tab))
	tab.close_pressed.connect(_on_tab_close_pressed.bind(tab))
	_buttons.append(tab)


func _tabs() -> SideTabContainer:
	return get_parent() as SideTabContainer


func _can_use_tabs() -> bool:
	return is_inside_tree() and get_parent() is SideTabContainer


func _tab_count() -> int:
	if not _can_use_tabs():
		return 0
	return _tabs().get_tab_count()


func _get_minimum_size() -> Vector2:
	var count := _tab_count()
	if count <= 0:
		return Vector2(18.0, 0.0)
	var width := 18.0
	for tab in _buttons:
		width = maxf(width, tab.get_combined_minimum_size().x)
	return Vector2(width, _tab_height() * float(count))


func _tab_height() -> float:
	return 16.0


func _slot_y(tab_idx: int, drag_from: int, drop_idx: int) -> float:
	var order := _visual_order(drag_from, drop_idx)
	var slot := order.find(tab_idx)
	if slot < 0:
		slot = tab_idx
	return float(slot) * _tab_height()


func _visual_order(drag_from: int, drop_idx: int) -> Array[int]:
	var count := _tab_count()
	var order: Array[int] = []
	for i in count:
		if i != drag_from:
			order.append(i)
	if drag_from >= 0:
		var insert_at := drag_from if drop_idx < 0 else drop_idx
		order.insert(clampi(insert_at, 0, order.size()), drag_from)
	return order


func _drop_idx_at_y(y: float) -> int:
	var count := _tab_count()
	if count <= 1:
		return 0
	return clampi(int(floor(y / _tab_height())), 0, count - 1)


func _on_tab_button_down(tab: SideTab) -> void:
	var idx := _buttons.find(tab)
	if idx < 0:
		return
	_press_idx = idx
	_press_local = get_local_mouse_position()
	_tabs().current_tab = idx
	set_process_input(true)
	set_process(true)


func _on_tab_close_pressed(tab: SideTab) -> void:
	var idx := _buttons.find(tab)
	if idx < 0:
		return
	_tabs().close_tab(idx)


func _on_released() -> void:
	if _press_idx < 0 and not _dragging:
		return
	if _dragging:
		var from_idx := _drag_from
		var to_idx := _drop_idx
		_tabs().rearrange_tab(from_idx, to_idx)
		_remap_visual(from_idx, to_idx)
		_remap_buttons(from_idx, to_idx)
	_dragging = false
	_drag_from = -1
	_drop_idx = -1
	_press_idx = -1
	for i in _buttons.size():
		_buttons[i].set_dragging(false)
		_buttons[i].set_selected(i == _tabs().current_tab)
	set_process_input(false)
	set_process(true)
	_layout_tabs()


func _on_mouse_moved(local_pos: Vector2) -> void:
	if _press_idx >= 0 and not _dragging and local_pos.distance_to(_press_local) >= 3.0:
		_dragging = true
		_drag_from = _press_idx
		_drop_idx = _press_idx
		_drag_grab = _press_local.y - _visual_y[_press_idx]
		_drag_y = _visual_y[_press_idx]
		_last_step_usec = Time.get_ticks_usec()
		_buttons[_press_idx].set_dragging(true)
		move_child(_buttons[_press_idx], get_child_count() - 1)
		set_process(true)
	if _dragging:
		_drop_idx = _drop_idx_at_y(local_pos.y)
		var now := Time.get_ticks_usec()
		var delta := clampf(float(now - _last_step_usec) / 1_000_000.0, 0.0, 0.05)
		_last_step_usec = now
		_step_visuals(delta)


func _remap_visual(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx or _visual_y.is_empty():
		return
	var ys: Array = []
	var vs: Array = []
	for i in _visual_y.size():
		ys.append(_visual_y[i])
		vs.append(_velocity[i])
	var moved_y: float = ys.pop_at(from_idx)
	var moved_v: float = vs.pop_at(from_idx)
	ys.insert(to_idx, moved_y)
	vs.insert(to_idx, moved_v)
	for i in ys.size():
		_visual_y[i] = ys[i]
		_velocity[i] = vs[i]


func _remap_buttons(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	var moved: SideTab = _buttons.pop_at(from_idx)
	_buttons.insert(to_idx, moved)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_on_released()
	elif event is InputEventMouseMotion:
		_on_mouse_moved(get_local_mouse_position())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_tabs()


func _process(delta: float) -> void:
	_step_visuals(delta)


func _step_visuals(delta: float) -> void:
	var count := _tab_count()
	if _visual_y.size() != count or _buttons.size() != count:
		refresh()
		count = _tab_count()
	if count <= 0:
		set_process(false)
		return
	if _dragging:
		_drop_idx = _drop_idx_at_y(get_local_mouse_position().y)
		var mouse_y := get_local_mouse_position().y - _drag_grab
		mouse_y = clampf(mouse_y, 0.0, maxf(0.0, float(count - 1) * _tab_height()))
		_drag_y = mouse_y
		_visual_y[_drag_from] = mouse_y
		_velocity[_drag_from] = 0.0
	var moving := _dragging
	for i in count:
		if _dragging and i == _drag_from:
			continue
		var target := _slot_y(i, _drag_from, _drop_idx)
		var state := _damp(_visual_y[i], target, _velocity[i], delta)
		_visual_y[i] = state.x
		_velocity[i] = state.y
		if absf(_visual_y[i] - target) > 0.05 or absf(_velocity[i]) > 0.05:
			moving = true
	_layout_tabs()
	if not moving:
		set_process(false)


func _layout_tabs() -> void:
	for i in _buttons.size():
		var tab := _buttons[i]
		var min_size := tab.get_combined_minimum_size()
		var y := _visual_y[i] if i < _visual_y.size() else float(i) * _tab_height()
		tab.size = Vector2(min_size.x, _tab_height())
		tab.position = Vector2(size.x - tab.size.x, y)


func _damp(current: float, target: float, velocity: float, delta: float) -> Vector2:
	var omega := 2.0 / 0.12
	var x := omega * delta
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - target
	var temp := (velocity + omega * change) * delta
	var new_vel := (velocity - omega * temp) * e
	var new_pos := target + (change + temp) * e
	if (target - current) * (new_pos - target) > 0.0:
		return Vector2(target, 0.0)
	return Vector2(new_pos, new_vel)
