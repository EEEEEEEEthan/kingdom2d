@tool
extends EditorPlugin

const _DOCK_SCENE := preload("res://addons/godot_github_cursor_kanban/dock.tscn")

var _dock: Control


func _enter_tree() -> void:
	_dock = _DOCK_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_BL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null
