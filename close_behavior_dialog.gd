extends Window

signal exit_chosen(save_preference: bool)
signal hide_chosen(save_preference: bool)


func popup_near_mouse() -> void:
	%WindowPresenter.popup_near_mouse()
