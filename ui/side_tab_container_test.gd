extends SceneTree

func _init() -> void:
	var ok := true
	var host := Control.new()
	host.size = Vector2(240, 128)
	root.add_child(host)
	var tabs: SideTabContainer = load("res://ui/side_tab_container.tscn").instantiate()
	host.add_child(tabs)
	tabs.size = Vector2(240, 128)
	for title in ["甲", "乙", "丙"]:
		var page := Label.new()
		page.name = title
		page.text = title
		tabs.add_child(page)
	await process_frame
	await process_frame
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
