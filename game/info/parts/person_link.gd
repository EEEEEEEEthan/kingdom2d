@tool
extends HBoxContainer
class_name PersonLink

## 头像加可点的名字。住户列表和岗位列表共用这一份。

signal pressed

@export var text := "":
	set(value):
		text = value
		_apply_text()

@export var character_id := 0:
	set(value):
		character_id = value
		_apply_avatar()

@export var show_avatar := true:
	set(value):
		show_avatar = value
		_apply_avatar()

@export var link_enabled := true:
	set(value):
		link_enabled = value
		_apply_link()


func set_character(character: Character) -> void:
	character_id = character.id
	text = character.display_name()
	show_avatar = true
	link_enabled = true


func set_vacant(label := "空位") -> void:
	show_avatar = false
	link_enabled = false
	text = label


func _ready() -> void:
	if not %Name.pressed.is_connected(_on_name_pressed):
		%Name.pressed.connect(_on_name_pressed)
	_apply_text()
	_apply_avatar()
	_apply_link()


func _on_name_pressed() -> void:
	pressed.emit()


func _apply_text() -> void:
	if is_node_ready():
		%Name.text = text


func _apply_avatar() -> void:
	if not is_node_ready():
		return
	%Avatar.visible = show_avatar
	if show_avatar:
		%Avatar.apply_id(character_id)


func _apply_link() -> void:
	if is_node_ready():
		%Name.disabled = not link_enabled
