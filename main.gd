extends Node


func request_quit() -> void:
	%QuitConfirmDialog.visible = true


func _on_quit_confirm_dialog_confirmed() -> void:
	get_tree().quit()
