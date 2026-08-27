extends Control

@onready var _status_label: RichTextLabel = %StatusLabel

var character: Character:
	set(value):
		character = value
		if not is_node_ready():
			await ready
		_status_label.refresh(character)


func _process(_delta: float) -> void:
	if not character:
		return
	_status_label.refresh(character)
