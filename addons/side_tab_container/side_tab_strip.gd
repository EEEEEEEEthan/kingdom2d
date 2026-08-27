@tool
extends VBoxContainer
class_name SideTabStrip

var _buttons: Array[SideTab] = []
var _dragging := false
var _drag_from := -1
var _drag_tab: SideTab
var _press_idx := -1
var _press_local := Vector2.ZERO


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
	for i in count:
		_buttons[i].set_tab_title(_tabs().get_tab_title(i))
		_buttons[i].set_selected(i == _tabs().current_tab)
		_buttons[i].set_dragging(_dragging)
	update_minimum_size()


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


func _on_tab_button_down(tab: SideTab) -> void:
	var idx := _buttons.find(tab)
	if idx < 0:
		return
	_press_idx = idx
	_press_local = get_local_mouse_position()
	_tabs().current_tab = idx
	set_process_input(true)


func _on_tab_close_pressed(tab: SideTab) -> void:
	var idx := _buttons.find(tab)
	if idx < 0:
		return
	_tabs().close_tab(idx)


func _on_released() -> void:
	if _press_idx < 0 and not _dragging:
		return
	if _dragging and _drag_tab:
		var to_idx := _buttons.find(_drag_tab)
		_tabs().rearrange_tab(_drag_from, to_idx)
	_dragging = false
	_drag_from = -1
	_drag_tab = null
	_press_idx = -1
	for i in _buttons.size():
		_buttons[i].set_dragging(false)
		_buttons[i].set_selected(i == _tabs().current_tab)
	set_process_input(false)


func _on_mouse_moved(local_pos: Vector2) -> void:
	if _press_idx >= 0 and not _dragging and local_pos.distance_to(_press_local) >= 3.0:
		_dragging = true
		_drag_from = _press_idx
		_drag_tab = _buttons[_press_idx]
		_drag_tab.set_dragging(true)
	if not _dragging or _drag_tab == null:
		return
	var to_idx := _drop_idx_at_y(local_pos.y)
	if to_idx == _buttons.find(_drag_tab):
		return
	move_child(_drag_tab, _child_index_for_slot(to_idx))
	_sync_buttons()


func _drop_idx_at_y(y: float) -> int:
	var tabs: Array[SideTab] = []
	for child in get_children():
		if child is SideTab:
			tabs.append(child)
	if tabs.is_empty():
		return 0
	for i in tabs.size():
		if y < tabs[i].position.y + tabs[i].size.y * 0.5:
			return i
	return tabs.size() - 1


func _child_index_for_slot(tab_slot: int) -> int:
	var slot := 0
	for i in get_child_count():
		if get_child(i) is SideTab:
			if slot == tab_slot:
				return i
			slot += 1
	return get_child_count()


func _sync_buttons() -> void:
	_buttons.clear()
	for child in get_children():
		if child is SideTab:
			_buttons.append(child)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_on_released()
	elif event is InputEventMouseMotion:
		_on_mouse_moved(get_local_mouse_position())
