extends SceneTree

const _OUTLINE := preload("res://game/hover_outline.gd")


func _initialize() -> void:
	load("res://game/game.gd")
	load("res://game/characters/character.gd")
	load("res://game/structures/gatherer_hut.gd")
	load("res://game/structures/structure_config.gd")
	load("res://game/info/info_browser.gd")
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	host.add_child(game)
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	host.add_child(browser)
	await process_frame
	game._clear()
	await process_frame
	var character = game.spawn_resident_at_cell(220)
	character.set_process(false)
	var hut = load("res://game/structures/structure_config.gd").gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 280)
	await process_frame
	var camera := game.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	browser.open_resident(character)
	await process_frame
	if browser.inspect_target() != character:
		push_error("打开居民页应锁定该角色")
		quit(1)
		return
	if absi(int(camera.position.x) - int(character.global_position.x)) > 1:
		push_error("镜头应跟到角色，camera=%s character=%s" % [camera.position.x, character.global_position.x])
		quit(1)
		return
	if not _ghost_visible(character.get_node("HoverOutline")):
		push_error("打开居民页应高亮角色")
		quit(1)
		return
	character.position.x += 48.0
	await process_frame
	if absi(int(camera.position.x) - int(character.global_position.x)) > 1:
		push_error("角色移动后镜头应继续跟随")
		quit(1)
		return
	camera._drag_loop_active = true
	camera.position.x = character.global_position.x + 120.0
	camera._process(0.016)
	if absi(int(camera.position.x) - int(character.global_position.x + 120.0)) > 1:
		push_error("按住拖动时不该被拉回")
		quit(1)
		return
	camera._drag_loop_active = false
	camera._process(0.016)
	if absi(int(camera.position.x) - int(character.global_position.x)) > 1:
		push_error("松开后镜头应回到角色")
		quit(1)
		return
	browser.open_structure(hut)
	await process_frame
	if browser.inspect_target() != hut:
		push_error("打开建筑页应锁定该建筑")
		quit(1)
		return
	if absi(int(camera.position.x) - int(hut.global_position.x)) > 1:
		push_error("镜头应跟到建筑")
		quit(1)
		return
	if _ghost_visible(character.get_node("HoverOutline")) or not _ghost_visible(hut.get_node("HoverOutline")):
		push_error("高亮应改到建筑")
		quit(1)
		return
	browser.open_settings()
	await process_frame
	if browser.inspect_target() != null or _OUTLINE._pinned != null:
		push_error("设置页应取消高亮和跟随")
		quit(1)
		return
	if _ghost_visible(hut.get_node("HoverOutline")):
		push_error("设置页不应再描建筑")
		quit(1)
		return
	var parked: float = camera.position.x
	hut.position.x += 30.0
	await process_frame
	if not is_equal_approx(camera.position.x, parked):
		push_error("离开检查页后镜头不该继续跟")
		quit(1)
		return
	browser.open_resident(character)
	await process_frame
	browser.hide()
	await process_frame
	if _OUTLINE._pinned != null or _ghost_visible(character.get_node("HoverOutline")):
		push_error("关掉窗口应取消高亮")
		quit(1)
		return
	browser.open_resident(character)
	await process_frame
	camera.zoom = Vector2(4, 4)
	camera.position.y = character.global_position.y
	await _shot(game, host, "/opt/cursor/artifacts/inspect_follow.png")
	camera._drag_loop_active = true
	camera.position.x = character.global_position.x + 80.0
	await _shot(game, host, "/opt/cursor/artifacts/inspect_dragged.png")
	camera._drag_loop_active = false
	camera._process(0.016)
	await _shot(game, host, "/opt/cursor/artifacts/inspect_released.png")
	browser.open_settings()
	await process_frame
	await _shot(game, host, "/opt/cursor/artifacts/inspect_cleared.png")
	camera.zoom = Vector2.ONE
	print("inspect_focus_ok")
	quit(0)


func _shot(game: Node, host: Node, path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 64)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := Node2D.new()
	viewport.add_child(holder)
	game.reparent(holder)
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	game.reparent(host)
	viewport.queue_free()
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	if image == null:
		push_error("没拿到画面")
		return
	image.save_png(path)


func _ghost_visible(outline: Node) -> bool:
	for child in outline.get_children():
		if child is Sprite2D and child.visible:
			return true
	return false
