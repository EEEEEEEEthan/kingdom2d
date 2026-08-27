extends SceneTree

func _init() -> void:
	var ok := true
	var browser := preload("res://browser/browser.tscn").instantiate()
	root.add_child(browser)
	await process_frame
	var a := Label.new()
	a.text = "甲"
	browser.add_page("甲", a)
	await process_frame
	var tabs: SideTabContainer = browser.get_node("%SideTabContainer")
	ok = _check(ok, tabs.get_tab_count() == 1, "tab count")
	ok = _check(ok, tabs.get_tab_title(0) == "甲", "title")
	ok = _check(ok, tabs.get_tab_control(0).get_node("Content").get_child(0) == a, "content")
	ok = _check(ok, browser.visible, "show on add")
	browser.add_page("甲", a)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 1, "reuse page")
	var b := Label.new()
	b.text = "乙"
	browser.add_page("乙", b)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 2, "second page")
	ok = _check(ok, tabs.get_tab_title(1) == "乙", "second title")
	browser.add_page("甲", a)
	await process_frame
	ok = _check(ok, tabs.current_tab == 0, "refocus first")
	tabs.close_tab(0)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 1, "close tab")
	ok = _check(ok, browser.visible, "keep open with tabs")
	tabs.close_tab(0)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 0, "close last")
	ok = _check(ok, browser.visible == false, "hide when empty")
	if ok:
		print("Browser pages tests passed")
		quit(0)
	else:
		print("Browser pages tests failed")
		quit(1)


func _check(ok: bool, cond: bool, label: String) -> bool:
	if not cond:
		push_error("FAIL: " + label)
		return false
	print("ok: " + label)
	return ok
