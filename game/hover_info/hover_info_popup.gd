extends PopupPanel
class_name HoverInfoPopup

var source: Control
var link: String = ""
var pinned := false
var hovered := false


func setup(hover_source: Control, hover_link: String, content: Control) -> void:
	%PinLogic.setup(hover_source, hover_link, content)
