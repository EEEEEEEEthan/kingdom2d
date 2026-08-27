class_name HoverInfoToken
extends RefCounted

var url: String = ""


func get_bbcode(display_text: String) -> String:
	return "[url=%s][color=#ffd541]%s[/color][/url]" % [url, display_text]
