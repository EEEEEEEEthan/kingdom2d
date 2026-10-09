extends SceneTree

const _CARD := preload("res://addons/godot_github_cursor_kanban/card.tscn")


var _card: PanelContainer


func _initialize() -> void:
	_card = _CARD.instantiate()
	_card.apply({
		"id": "bc-1",
		"name": "工作中",
		"working": true,
	})
	root.add_child(_card)
	process_frame.connect(_check, CONNECT_ONE_SHOT)


func _check() -> void:
	var status := _card.get_node(^"%SessionStatus") as TextureRect
	if not status.visible or status.texture == null:
		_fail("工作中应显示转圈")
		return
	if not _card.is_processing():
		_fail("工作中应转动")
		return
	_card.apply({
		"id": "bc-1",
		"name": "空闲",
		"working": false,
	})
	if status.visible or _card.is_processing():
		_fail("空闲不显示状态")
		return
	if not is_equal_approx(status.rotation, 0.0):
		_fail("空闲时转圈应停回原位")
		return
	print("card_status_test ok")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
