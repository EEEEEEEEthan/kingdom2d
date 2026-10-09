@tool
extends EditorPlugin

const _DOCK_SCENE := preload("res://addons/godot_github_cursor_kanban/dock.tscn")

var _dock: EditorDock


func _enter_tree() -> void:
	var content := _DOCK_SCENE.instantiate() as Control
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dock = EditorDock.new()
	_dock.title = "看板"
	# 独立 layout_key，不沿用上次停在错误槽位的布局记录。
	_dock.layout_key = "godot_github_cursor_kanban"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_BR
	_dock.add_child(content)
	add_dock(_dock)


func _exit_tree() -> void:
	if _dock:
		remove_dock(_dock)
		_dock.free()
		_dock = null
