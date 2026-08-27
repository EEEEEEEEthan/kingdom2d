@tool
extends Control
class_name SideTabStrip

var _tab_buttons: Array[TabButton] = []
var _visual_y: PackedFloat32Array = PackedFloat32Array()
var _velocity: PackedFloat32Array = PackedFloat32Array()
var _dragging := false
var _drag_from := -1
var _drag_grab := 0.0
var _drop_idx := -1
var _press_idx := -1
var _press_local := Vector2.ZERO
var _last_step_usec := 0


func is_dragging() -> bool:
	return _dragging


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh()


func refresh() -> void:
	var count := _tab_count()
	var old := _visual_y.size()
	_visual_y.resize(count)
	_velocity.resize(count)
	for i in count:
		if i >= old:
			_visual_y[i] = _slot_y(i, -1, -1)
			_velocity[i] = 0.0
	while _tab_buttons.size() > count:
		_tab_buttons.pop_back().free()
	while _tab_buttons.size() < count:
		var tab_button := TabButton.new()
		add_child(tab_button)
		_tab_buttons.append(tab_button)
	for i in count:
		_tab_buttons[i].tab_idx = i
		_tab_buttons[i].sync_from_strip()
	_layout_tabs()
	set_process(true)
	update_minimum_size()


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
	for i in count:
		width = maxf(width, _title_width(i) + 18.0)
	return Vector2(width, _tab_height() * float(count))


func _tab_height() -> float:
	return 16.0


func _title_width(tab_idx: int) -> float:
	return _font().get_string_size(
			_tabs().get_tab_title(tab_idx), HORIZONTAL_ALIGNMENT_LEFT, -1, 10
	).x


func _font() -> Font:
	var font := get_theme_font(&"font", &"TabContainer")
	if font:
		return font
	return ThemeDB.fallback_font


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


func request_close(tab_idx: int) -> void:
	_tabs().close_tab(tab_idx)


func _layout_tabs() -> void:
	for i in _tab_buttons.size():
		var tab_button := _tab_buttons[i]
		var y := _visual_y[i] if i < _visual_y.size() else _slot_y(i, -1, -1)
		tab_button.position = Vector2(0.0, y)
		tab_button.size = Vector2(size.x, _tab_height())
		tab_button.z_index = 1 if _dragging and i == _drag_from else 0
		tab_button.sync_close_visible()


func _on_tab_pressed(tab_idx: int, local_pos: Vector2) -> void:
	_press_idx = tab_idx
	_press_local = local_pos
	_tabs().current_tab = tab_idx
	set_process_input(true)
	set_process(true)


func _on_tab_released() -> void:
	if _press_idx < 0 and not _dragging:
		return
	if _dragging:
		var from_idx := _drag_from
		var to_idx := _drop_idx
		_tabs().rearrange_tab(from_idx, to_idx)
		_remap_visual(from_idx, to_idx)
	_dragging = false
	_drag_from = -1
	_drop_idx = -1
	_press_idx = -1
	set_process_input(false)
	set_process(true)
	_layout_tabs()


func _on_tab_mouse_moved(local_pos: Vector2) -> void:
	if _press_idx >= 0 and not _dragging and local_pos.distance_to(_press_local) >= 3.0:
		_dragging = true
		_drag_from = _press_idx
		_drop_idx = _press_idx
		_drag_grab = _press_local.y - _visual_y[_press_idx]
		_last_step_usec = Time.get_ticks_usec()
		set_process(true)
	if not _dragging:
		return
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


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_on_tab_released()
	elif event is InputEventMouseMotion:
		_on_tab_mouse_moved(get_local_mouse_position())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_tabs()


func _process(delta: float) -> void:
	_step_visuals(delta)


func _step_visuals(delta: float) -> void:
	var count := _tab_count()
	if _visual_y.size() != count or _tab_buttons.size() != count:
		refresh()
		count = _tab_count()
	if count <= 0:
		set_process(false)
		return
	if _dragging:
		_drop_idx = _drop_idx_at_y(get_local_mouse_position().y)
		var mouse_y := get_local_mouse_position().y - _drag_grab
		mouse_y = clampf(mouse_y, 0.0, maxf(0.0, float(count - 1) * _tab_height()))
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


class TabButton extends Button:
	var tab_idx := 0
	var _close := CloseButton.new()

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		clip_text = true
		flat = true
		add_theme_font_size_override(&"font_size", 10)
		add_child(_close)
		button_down.connect(_on_button_down)
		button_up.connect(_on_button_up)
		mouse_entered.connect(_on_hover_changed)
		mouse_exited.connect(_on_hover_changed)

	func _strip() -> SideTabStrip:
		return get_parent() as SideTabStrip

	func sync_from_strip() -> void:
		var strip := _strip()
		text = strip._tabs().get_tab_title(tab_idx)
		var selected: bool = tab_idx == strip._tabs().current_tab
		var selected_style := _stylebox(&"tab_selected", selected)
		var hovered_style := _stylebox(&"tab_hovered", false)
		var unselected_style := _stylebox(&"tab_unselected", false)
		if selected:
			add_theme_stylebox_override(&"normal", selected_style)
			add_theme_stylebox_override(&"hover", selected_style)
			add_theme_stylebox_override(&"pressed", selected_style)
		else:
			add_theme_stylebox_override(&"normal", unselected_style)
			add_theme_stylebox_override(&"hover", hovered_style)
			add_theme_stylebox_override(&"pressed", hovered_style)
		var selected_color := get_theme_color(&"font_selected_color", &"TabContainer")
		var hovered_color := get_theme_color(&"font_hovered_color", &"TabContainer")
		var unselected_color := get_theme_color(&"font_unselected_color", &"TabContainer")
		if selected_color.a <= 0.0:
			selected_color = Color.WHITE
		if hovered_color.a <= 0.0:
			hovered_color = Color.WHITE
		if unselected_color.a <= 0.0:
			unselected_color = Color.WHITE
		var idle_color := selected_color if selected else unselected_color
		var hover_color := selected_color if selected else hovered_color
		add_theme_color_override(&"font_color", idle_color)
		add_theme_color_override(&"font_hover_color", hover_color)
		add_theme_color_override(&"font_pressed_color", hover_color)
		add_theme_color_override(&"font_focus_color", idle_color)
		add_theme_font_override(&"font", strip._font())
		_close.sync_icons()
		sync_close_visible()

	func sync_close_visible() -> void:
		_close.visible = is_hovered() and not _strip().is_dragging()
		_close.position = Vector2(size.x - 14.0, 3.0)
		_close.size = Vector2(10.0, 10.0)

	func _stylebox(style_name: StringName, selected: bool) -> StyleBox:
		var style := get_theme_stylebox(style_name, &"TabContainer")
		if style:
			return style
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.85, 0.63, 0.4, 1.0) if selected else Color(0.56, 0.34, 0.23, 1.0)
		return fallback

	func _on_button_down() -> void:
		_strip()._on_tab_pressed(tab_idx, get_local_mouse_position())

	func _on_button_up() -> void:
		_strip()._on_tab_released()

	func _on_hover_changed() -> void:
		sync_close_visible()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_strip()._on_tab_mouse_moved(
					event.position + position
			)


class CloseButton extends TextureButton:
	func _ready() -> void:
		ignore_texture_size = true
		custom_minimum_size = Vector2(10.0, 10.0)
		stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		pressed.connect(_on_pressed)

	func sync_icons() -> void:
		texture_normal = get_theme_icon(&"close", &"Window")
		texture_pressed = get_theme_icon(&"close_pressed", &"Window")

	func _on_pressed() -> void:
		var tab_button := get_parent() as TabButton
		(tab_button.get_parent() as SideTabStrip).request_close(tab_button.tab_idx)
