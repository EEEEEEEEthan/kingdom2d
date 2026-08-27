extends SceneTree

func _init() -> void:
	var ok := true
	var host := Control.new()
	host.size = Vector2(240, 128)
	root.add_child(host)
	var tabs := SideTabContainer.new()
	host.add_child(tabs)
	tabs.size = Vector2(240, 128)
	for title in ["甲", "乙乙乙乙", "丙"]:
		var page := Label.new()
		page.name = title
		page.text = title
		tabs.add_child(page)
	await process_frame
	tabs.size = Vector2(240, 128)
	tabs.notification(Container.NOTIFICATION_SORT_CHILDREN)
	ok = _check(ok, tabs.get_tab_count() == 3, "tab count")
	ok = _check(ok, tabs.current_tab == 0, "default tab")
	ok = _check(ok, tabs.get_tab_title(1) == "乙乙乙乙", "title from name")
	ok = _check(ok, tabs.get_tab_control(0).visible and not tabs.get_tab_control(1).visible, "only current visible")
	var strip: Control = tabs.get_node("TabStrip")
	ok = _check(ok, strip is VBoxContainer, "strip is vbox")
	ok = _check(ok, strip.position.x > 0.0, "tabs on right")
	ok = _check(ok, is_equal_approx(strip.position.x + strip.size.x, tabs.size.x), "strip flush right")
	ok = _check(ok, strip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "strip ignores empty hover")
	ok = _check(ok, strip.get_node("SideTabPlaceHolder") is InstancePlaceholder, "tab placeholder")
	var short_tab: Control = null
	for child in strip.get_children():
		if child is Button:
			short_tab = child
			break
	ok = _check(ok, short_tab != null, "tab is button")
	ok = _check(ok, short_tab.size.x < strip.size.x, "tab only as wide as itself")
	ok = _check(ok, short_tab.toggle_mode, "toggle mode")
	ok = _check(ok, short_tab.button_pressed, "current tab toggled")
	var group: ButtonGroup = short_tab.button_group
	ok = _check(ok, group != null, "has button group")
	var grouped := 0
	for child in strip.get_children():
		if child is Button:
			ok = _check(ok, child.button_group == group, "shared button group")
			grouped += 1
	ok = _check(ok, grouped == 3, "all tabs grouped")
	var close_button: BaseButton = short_tab.get_node("CloseButton")
	ok = _check(ok, close_button is TextureButton, "close is button")
	ok = _check(ok, close_button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "close on release")
	tabs.current_tab = 2
	ok = _check(ok, tabs.get_current_tab_control().name == "丙", "select tab")
	var toggled_count := 0
	for child in strip.get_children():
		if child is Button:
			if child.button_pressed:
				toggled_count += 1
				ok = _check(ok, child.text == "丙", "toggled tab matches current")
	ok = _check(ok, toggled_count == 1, "only current toggled")
	tabs.set_tab_title(2, "丙改")
	ok = _check(ok, tabs.get_tab_title(2) == "丙改", "set title")
	tabs.rearrange_tab(0, 2)
	ok = _check(ok, tabs.get_tab_title(0) == "乙乙乙乙", "reorder")
	ok = _check(ok, tabs.get_current_tab_control().name == "丙", "current follows node")
	tabs.close_tab(1)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 2, "close tab")
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
