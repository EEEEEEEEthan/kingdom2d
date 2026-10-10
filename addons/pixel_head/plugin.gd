@tool
extends EditorPlugin

const _TYPE_NAME := "PixelHead"
const _SCRIPT := preload("res://addons/pixel_head/pixel_head.gd")
const _ICON := preload("res://addons/pixel_head/icon.png")


func _enter_tree() -> void:
	add_custom_type(_TYPE_NAME, "Control", _SCRIPT, _ICON)


func _exit_tree() -> void:
	remove_custom_type(_TYPE_NAME)
