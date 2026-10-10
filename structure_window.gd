extends Window

var _structure_id := 0
var _game: Game


func _ready() -> void:
	visible = false


func open_for(structure_id: int) -> void:
	_game = get_node("../GameWindow/ViewportContainer/GameViewport/Game") as Game
	_structure_id = structure_id
	_rebuild()
	_open_near_mouse()


func _process(_delta: float) -> void:
	if visible:
		_refresh_labels()


func _site() -> WorkSite:
	if _game == null:
		return null
	var structure := _game.structure_manager.get_structure_by_id(_structure_id)
	if structure is WorkSite:
		return structure
	return null


func _rebuild() -> void:
	var site := _site()
	if site == null:
		hide()
		return
	title = String(site.config.name)
	for child in %Body.get_children():
		%Body.remove_child(child)
		child.free()
	if site.kind == WorkSite.Kind.WAREHOUSE:
		%Body.add_child(_label("仓库不能拆除"))
		%Body.add_child(_stock_label(site))
		var upgrade := Button.new()
		upgrade.text = "升级容量（原木 %d）" % WorkSite.CAPACITY_LOG_COST
		upgrade.pressed.connect(func() -> void:
			var current := _site()
			if current:
				current.order_capacity()
			_rebuild())
		%Body.add_child(upgrade)
	elif site.kind == WorkSite.Kind.LUMBER:
		%Body.add_child(_stock_label(site))
		_add_worker_buttons(site, "上岗", "离岗")
	elif site.kind == WorkSite.Kind.GUILD:
		%Body.add_child(_stock_label(site))
		_add_worker_buttons(site, "招募", "解除")
	elif site.kind == WorkSite.Kind.HOME:
		%Body.add_child(_label("住户 %s" % (_resident_text(site))))
		if site.config.id == StructureConfig.TypeId.TENT:
			var upgrade := Button.new()
			upgrade.text = "升级为小木屋（原木 %d）" % WorkSite.CABIN_LOG_COST
			upgrade.pressed.connect(func() -> void:
				var current := _site()
				if current:
					current.order_cabin()
				_rebuild())
			%Body.add_child(upgrade)
	%Body.add_child(_progress_label(site))


func _refresh_labels() -> void:
	var site := _site()
	if site == null:
		hide()
		return
	if site.config:
		title = String(site.config.name)
	for child in %Body.get_children():
		if child is Label and str(child.name).begins_with("Live"):
			child.text = _live_text(site, child.name)


func _add_worker_buttons(site: WorkSite, on_text: String, off_text: String) -> void:
	var characters := _game.character_manager.characters
	if characters.is_empty():
		%Body.add_child(_label("还没有居民"))
		return
	for character_id in characters.keys():
		var character := characters[character_id] as Character
		var button := Button.new()
		var working := character.job_structure_id == site.id
		button.text = "%s 居民%d" % [off_text if working else on_text, character.id]
		button.pressed.connect(_on_worker_pressed.bind(character.id, site.id))
		%Body.add_child(button)


func _on_worker_pressed(character_id: int, site_id: int) -> void:
	var character := _game.character_manager.characters.get(character_id) as Character
	var site := _game.structure_manager.get_structure_by_id(site_id)
	if character == null or not site is WorkSite:
		return
	if character.job_structure_id == site_id:
		character.clear_job()
	else:
		character.assign_job(site_id)
	_rebuild()


func _stock_label(site: WorkSite) -> Label:
	var label := _label("")
	label.name = "LiveStock"
	label.text = _stock_text(site)
	return label


func _progress_label(site: WorkSite) -> Label:
	var label := _label("")
	label.name = "LiveProgress"
	label.text = _progress_text(site)
	return label


func _live_text(site: WorkSite, node_name: String) -> String:
	if node_name == "LiveStock":
		return _stock_text(site)
	return _progress_text(site)


func _stock_text(site: WorkSite) -> String:
	if site.stock == null:
		return ""
	return "原木 %d / %d" % [site.stock.amount(LogisticsUnit.ITEM_WOOD), site.stock.capacity]


func _progress_text(site: WorkSite) -> String:
	if site.material_remaining <= 0:
		return ""
	return "还差 %d 份材料" % site.material_remaining


func _resident_text(site: WorkSite) -> String:
	if site.resident_id <= 0:
		return "空"
	return "居民%d" % site.resident_id


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _open_near_mouse() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	position = pos
	show()
	mode = MODE_WINDOWED
	grab_focus()
