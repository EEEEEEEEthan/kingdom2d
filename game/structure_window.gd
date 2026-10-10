extends PopupPanel

var _game: Game
var _structure_id := 0
var _people_signature := ""


func _ready() -> void:
	visible = false
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.561, 0.337, 0.231, 1)
	panel.set_content_margin_all(6)
	add_theme_stylebox_override("panel", panel)


func open_for(game: Game, structure_id: int) -> void:
	_game = game
	_structure_id = structure_id
	_people_signature = ""
	open_near_mouse()
	_refresh()


func open_near_mouse() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	popup(Rect2i(pos, size))


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _structure() -> Structure:
	if _game == null:
		return null
	return _game.structure_manager.get_structure_by_id(_structure_id)


func _refresh() -> void:
	var structure := _structure()
	if structure == null:
		hide()
		return
	title = structure.config.name
	%Info.text = structure.inspect_text() if structure is LoopStructure else structure.config.name
	var loop := structure as LoopStructure
	%Upgrade.visible = loop != null and (loop.kind == LoopStructure.Kind.WAREHOUSE or loop.kind == LoopStructure.Kind.LUMBER)
	if %Upgrade.visible:
		%Upgrade.text = "升级（%d 原木）" % LoopStructure.WAREHOUSE_UPGRADE_COST
		%Upgrade.disabled = loop.logs < LoopStructure.WAREHOUSE_UPGRADE_COST
	_rebuild_people(loop)


func _rebuild_people(loop: LoopStructure) -> void:
	var box := %People
	if loop == null:
		if _people_signature != "":
			_people_signature = ""
			for child in box.get_children():
				child.free()
		return
	var signature := _people_signature_for(loop)
	if signature == _people_signature:
		return
	_people_signature = signature
	for child in box.get_children():
		child.free()
	if loop.kind == LoopStructure.Kind.TENT or loop.kind == LoopStructure.Kind.HUT:
		for character in _game.character_manager.characters.values():
			if character.home_id == loop.id:
				var label := Label.new()
				label.text = "居民 %d" % character.id
				box.add_child(label)
		return
	if loop.kind != LoopStructure.Kind.LUMBER and loop.kind != LoopStructure.Kind.GUILD:
		return
	var occupied := _worker_count(loop.id) > 0 and loop.kind == LoopStructure.Kind.LUMBER
	for character in _game.character_manager.characters.values():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "居民 %d %s" % [character.id, _duty_name(character)]
		row.add_child(label)
		if character.workplace_id == loop.id:
			var clear_button := Button.new()
			clear_button.text = "撤下"
			clear_button.pressed.connect(character.clear_duty)
			row.add_child(clear_button)
		elif character.home_id != 0 and character.duty == Character.Duty.NONE and not occupied:
			var assign_button := Button.new()
			assign_button.text = "招募" if loop.kind == LoopStructure.Kind.GUILD else "安排"
			var resident: Character = character
			var duty := Character.Duty.BUILDER if loop.kind == LoopStructure.Kind.GUILD else Character.Duty.LUMBER
			assign_button.pressed.connect(func() -> void: resident.assign_duty(duty, loop.id))
			row.add_child(assign_button)
		box.add_child(row)


func _people_signature_for(loop: LoopStructure) -> String:
	var parts: PackedStringArray = []
	for character in _game.character_manager.characters.values():
		parts.append("%d:%d:%d:%d" % [character.id, character.home_id, character.duty, character.workplace_id])
	parts.append(str(loop.id))
	parts.append(str(loop.kind))
	return "|".join(parts)


func _worker_count(workplace_id: int) -> int:
	var count := 0
	for character in _game.character_manager.characters.values():
		if character.workplace_id == workplace_id:
			count += 1
	return count


func _duty_name(character: Character) -> String:
	match character.duty:
		Character.Duty.LUMBER:
			return "伐木"
		Character.Duty.BUILDER:
			return "建筑工"
	return "空闲"


func _on_upgrade_pressed() -> void:
	var loop := _structure() as LoopStructure
	if loop == null or (loop.kind != LoopStructure.Kind.WAREHOUSE and loop.kind != LoopStructure.Kind.LUMBER):
		return
	if loop.logs < LoopStructure.WAREHOUSE_UPGRADE_COST:
		return
	loop.logs -= LoopStructure.WAREHOUSE_UPGRADE_COST
	loop.level += 1
