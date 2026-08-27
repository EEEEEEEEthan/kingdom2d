extends SceneTree

func _init() -> void:
	var ok := true
	var host := Control.new()
	host.size = Vector2(240, 128)
	root.add_child(host)
	var tabs := SideTabContainer.new()
	host.add_child(tabs)
	tabs.size = Vector2(240, 128)
	for title in ["甲", "乙", "丙"]:
		var page := Label.new()
		page.name = title
		page.text = title
		tabs.add_child(page)
	await process_frame
	tabs.size = Vector2(240, 128)
	tabs.notification(Container.NOTIFICATION_SORT_CHILDREN)
	ok = _check(ok, tabs.get_tab_count() == 3, "tab count")
	ok = _check(ok, tabs.current_tab == 0, "default tab")
	ok = _check(ok, tabs.get_tab_title(1) == "乙", "title from name")
	ok = _check(ok, tabs.get_tab_control(0).visible and not tabs.get_tab_control(1).visible, "only current visible")
	tabs.current_tab = 2
	ok = _check(ok, tabs.get_current_tab_control().name == "丙", "select tab")
	tabs.set_tab_title(2, "丙改")
	ok = _check(ok, tabs.get_tab_title(2) == "丙改", "set title")
	tabs.rearrange_tab(0, 2)
	ok = _check(ok, tabs.get_tab_title(0) == "乙", "reorder")
	ok = _check(ok, tabs.get_current_tab_control().name == "丙", "current follows node")
	var strip: Control = tabs.get_node("TabStrip")
	ok = _check(ok, strip.position.x > 0.0, "tabs on right")
	ok = _check(ok, is_equal_approx(strip.position.x + strip.size.x, tabs.size.x), "strip flush right")
	ok = _check(ok, strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "strip ignores empty hover")
	var tab_button := strip.get_child(0) as Button
	ok = _check(ok, tab_button != null, "tab is button")
	ok = _check(ok, tab_button.mouse_filter == Control.MOUSE_FILTER_STOP, "tab button stops mouse")
	var close_button := tab_button.get_child(0) as TextureButton
	ok = _check(ok, close_button != null, "close is texture button")
	ok = _check(ok, close_button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "close on release")
	close_button.button_down.emit()
	ok = _check(ok, tabs.get_tab_count() == 3, "press does not close")
	close_button.pressed.emit()
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 2, "release closes")
	tabs.close_tab(0)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 1, "close tab")
	if ok:
		print("SideTabContainer tests passed")
		quit(0)
	else:
		print("SideTabContainer tests failed")
		quit(1)


func _check(ok: bool, cond: bool, label: String) -> bool:
	if not cond:
		push_error("FAIL: " + label)
		return false
	print("ok: " + label)
	return ok
