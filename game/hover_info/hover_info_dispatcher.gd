extends Node

var current_source: Control
var current_link: String = ""

var _callbacks: Dictionary = {}
var _active_keys: Dictionary = {}
var _next_id: int = 0
var _hover_elapsed: float = 0.0


func register_hover_info(on_hover: Callable) -> HoverInfoToken:
	_next_id += 1
	var token := HoverInfoToken.new()
	token.url = "hover_%s" % _next_id
	_callbacks[token.url] = on_hover
	return token


func create_simple(title: String, content: String) -> Control:
	var info := preload("res://game/hover_info/simple_hover_info.tscn").instantiate()
	info.setup(title, content)
	return info


func is_current(source: Control, link: String) -> bool:
	return current_source == source and current_link == link


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	if current_source == null or current_link.is_empty():
		_hover_elapsed = 0.0
		return
	if not is_instance_valid(current_source):
		current_source = null
		current_link = ""
		return
	var key := _action_key(current_source, current_link)
	if _active_keys.has(key):
		return
	_hover_elapsed += delta
	if _hover_elapsed < 0.2:
		return
	_open_popup(current_source, current_link)


func _set_current(source: Control, link: String) -> void:
	if current_source == source and current_link == link:
		return
	current_source = source
	current_link = link
	_hover_elapsed = 0.0


func _clear_current(source: Control, link: String) -> void:
	if current_source == source and current_link == link:
		current_source = null
		current_link = ""
		_hover_elapsed = 0.0


func _action_key(source: Control, link: String) -> String:
	return "%s:%s" % [source.get_instance_id(), link]


func _open_popup(source: Control, link: String) -> void:
	var key := _action_key(source, link)
	if _active_keys.has(key):
		return
	var on_hover: Callable = _callbacks.get(link, Callable())
	if not on_hover.is_valid():
		return
	var content: Variant = on_hover.call()
	if not content is Control:
		return
	_active_keys[key] = true
	var hover_popup: HoverInfoPopup = (
			preload("res://game/hover_info/hover_info_popup.tscn").instantiate()
	)
	var parent_popup := _find_parent_hover_popup(source)
	if parent_popup:
		parent_popup.add_child(hover_popup)
	else:
		source.get_window().add_child(hover_popup)
	hover_popup.tree_exited.connect(func() -> void: _active_keys.erase(key))
	hover_popup.setup(source, link, content as Control)


func _find_parent_hover_popup(source: Control) -> HoverInfoPopup:
	var node: Node = source
	while node:
		if node is HoverInfoPopup:
			return node as HoverInfoPopup
		node = node.get_parent()
	return null


func _on_node_added(node: Node) -> void:
	if not node is RichTextLabel:
		return
	var label := node as RichTextLabel
	label.meta_underlined = false
	var on_hover_started := func(meta: Variant) -> void:
		_set_current(label, str(meta))
	var on_hover_ended := func(meta: Variant) -> void:
		_clear_current(label, str(meta))
	label.meta_hover_started.connect(on_hover_started)
	label.meta_hover_ended.connect(on_hover_ended)
	label.tree_exited.connect(
			func() -> void:
				if label.meta_hover_started.is_connected(on_hover_started):
					label.meta_hover_started.disconnect(on_hover_started)
				if label.meta_hover_ended.is_connected(on_hover_ended):
					label.meta_hover_ended.disconnect(on_hover_ended)
	, CONNECT_ONE_SHOT)
