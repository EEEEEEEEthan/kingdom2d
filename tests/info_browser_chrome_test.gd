extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var browser := (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	await process_frame
	if not browser.borderless:
		push_error("信息浏览器应无系统边框")
		quit(1)
		return
	if not browser.transparent:
		push_error("信息浏览器应允许透明")
		quit(1)
		return
	if browser.get_node_or_null("%CloseButton") == null:
		push_error("缺少自绘关闭按钮")
		quit(1)
		return
	var settings := (load("res://game/info/settings_page.tscn") as PackedScene).instantiate()
	browser.get_node("%PageHost").add_child(settings)
	await process_frame
	if settings.get_node_or_null("%ResetConfirmDialog") != null:
		push_error("重置确认不应再使用系统对话框")
		quit(1)
		return
	settings.get_node("%ResetGame").pressed.emit()
	if not settings.get_node("%ResetConfirm").visible:
		push_error("点重置后应显示窗内确认")
		quit(1)
		return
	quit(0)
