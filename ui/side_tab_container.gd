@tool
extends Container
class_name SideTabContainer

signal tab_changed(tab: int)
signal tab_selected(tab: int)
signal tab_close_pressed(tab: int)
signal active_tab_rearranged(idx_to: int)

var _tab_strip := SideTabStrip.new()

var current_tab: int = -1:
	set(value):
		var count := get_tab_count()
		if count <= 0:
			if current_tab != -1:
				current_tab = -1
				tab_changed.emit(-1)
			_apply_page_visibility()
			return
		var next := clampi(value, 0, count - 1)
		var previous := get_current_tab_control()
		if current_tab == next:
			_apply_page_visibility()
			return
		current_tab = next
		_apply_page_visibility()
		if previous != get_tab_control(next):
			tab_selected.emit(current_tab)
			tab_changed.emit(current_tab)
		_tab_strip.refresh()
		queue_sort()


func _init() -> void:
	_tab_strip.name = "TabStrip"
	add_child(_tab_strip, false, Node.INTERNAL_MODE_BACK)


func get_tab_count() -> int:
	return get_tab_controls().size()


func get_tab_controls() -> Array[Control]:
	var pages: Array[Control] = []
	for child in get_children():
		if child == _tab_strip:
			continue
		if child is Control and not child.is_queued_for_deletion():
			pages.append(child)
	return pages


func get_tab_control(tab_idx: int) -> Control:
	return get_tab_controls()[tab_idx]


func get_current_tab_control() -> Control:
	if current_tab < 0 or current_tab >= get_tab_count():
		return null
	return get_tab_control(current_tab)


func get_tab_title(tab_idx: int) -> String:
	var page := get_tab_control(tab_idx)
	if page.has_meta("tab_title"):
		return String(page.get_meta("tab_title"))
	return page.name


func set_tab_title(tab_idx: int, title: String) -> void:
	get_tab_control(tab_idx).set_meta("tab_title", title)
	update_minimum_size()
	queue_sort()
	_tab_strip.refresh()


func close_tab(tab_idx: int) -> void:
	tab_close_pressed.emit(tab_idx)
	get_tab_control(tab_idx).queue_free()


func rearrange_tab(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	var page := get_tab_control(from_idx)
	var current_page := get_current_tab_control()
	move_child(page, to_idx)
	current_tab = get_tab_controls().find(current_page)
	if page == current_page:
		active_tab_rearranged.emit(current_tab)
	queue_sort()


func _enter_tree() -> void:
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
		child_exiting_tree.connect(_on_child_exiting_tree)
		child_order_changed.connect(_on_child_order_changed)


func _ready() -> void:
	if current_tab < 0 and get_tab_count() > 0:
		current_tab = 0
	else:
		_apply_page_visibility()


func _get_minimum_size() -> Vector2:
	var strip_min := _tab_strip.get_combined_minimum_size()
	var page_min := Vector2.ZERO
	for page in get_tab_controls():
		page_min = page_min.max(page.get_combined_minimum_size())
	return Vector2(page_min.x + strip_min.x, maxf(page_min.y, strip_min.y))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_pages()


func _apply_page_visibility() -> void:
	var pages := get_tab_controls()
	for i in pages.size():
		pages[i].visible = i == current_tab


func _sort_pages() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var strip_width := _tab_strip.get_combined_minimum_size().x
	var page_rect := Rect2(0.0, 0.0, size.x - strip_width, size.y)
	var strip_rect := Rect2(size.x - strip_width, 0.0, strip_width, size.y)
	fit_child_in_rect(_tab_strip, strip_rect)
	for page in get_tab_controls():
		fit_child_in_rect(page, page_rect)


func _on_child_entered_tree(child: Node) -> void:
	if child == _tab_strip or child.get_parent() != self:
		return
	if child is Control:
		if not child.renamed.is_connected(_on_page_renamed):
			child.renamed.connect(_on_page_renamed)
		if current_tab < 0:
			current_tab = 0
		update_minimum_size()
		queue_sort()
		_tab_strip.refresh()


func _on_child_exiting_tree(child: Node) -> void:
	if child == _tab_strip or child.get_parent() != self:
		return
	if child is Control and child.renamed.is_connected(_on_page_renamed):
		child.renamed.disconnect(_on_page_renamed)
	var remaining: Array[Control] = []
	for page in get_tab_controls():
		if page != child:
			remaining.append(page)
	if remaining.is_empty():
		current_tab = -1
	elif current_tab >= remaining.size():
		current_tab = remaining.size() - 1
	else:
		_apply_page_visibility()
	update_minimum_size()
	queue_sort()
	_tab_strip.refresh()


func _on_child_order_changed() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_apply_page_visibility()
	update_minimum_size()
	queue_sort()
	if _tab_strip.is_dragging():
		return
	_tab_strip.refresh()


func _on_page_renamed() -> void:
	update_minimum_size()
	_tab_strip.refresh()
