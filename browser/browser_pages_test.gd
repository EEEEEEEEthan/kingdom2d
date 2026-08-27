extends SceneTree

func _init() -> void:
	var ok := true
	var browser := preload("res://browser/browser.tscn").instantiate()
	root.add_child(browser)
	await process_frame
	browser.open_settings()
	await process_frame
	var tabs: SideTabContainer = browser.get_node("%SideTabContainer")
	ok = _check(ok, tabs.get_tab_count() == 1, "settings tab count")
	ok = _check(ok, tabs.get_tab_title(0) == "设置", "settings title")
	ok = _check(ok, tabs.get_tab_control(0).get_node("Content").get_child(0) is Control, "settings is control")
	ok = _check(ok, tabs.get_tab_control(0).get_node("Content").get_child(0) is Window == false, "settings not window")
	browser.open_settings()
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 1, "settings reused")
	var character := preload("res://game/characters/character.tscn").instantiate() as Character
	character.id = 7
	root.add_child(character)
	await browser.open_inspector(character)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 2, "inspector tab added")
	ok = _check(ok, tabs.get_tab_title(1) == "角色 7", "inspector title")
	ok = _check(ok, tabs.get_tab_control(1).get_node("Content").get_child(0) is InspectorPanel, "inspector is control")
	await browser.open_inspector(character)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 2, "inspector reused")
	tabs.close_tab(0)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 1, "close settings")
	ok = _check(ok, tabs.get_tab_title(0) == "角色 7", "inspector remains")
	tabs.close_tab(0)
	await process_frame
	ok = _check(ok, tabs.get_tab_count() == 0, "close last tab")
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
