extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/game_builder.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	var manager := game.structure_manager as StructureManager
	var cell := 3
	var first := StructureConfig.bush.instantiate() as Structure
	if manager.add_structure(first, cell, true) != StructureManager.AddError.OK:
		push_error("空格子 dry_run 应为 OK")
		quit(1)
		return
	if first.id != 0 or first.get_parent() != null or manager.structures.size() != 0:
		push_error("dry_run 不应改 id、父节点或登记表")
		quit(1)
		return
	if manager.add_structure(first, cell) != StructureManager.AddError.OK:
		push_error("空格子应能放下")
		quit(1)
		return
	if manager.index_to_structures[cell] != first or not manager.structures.has(first.id):
		push_error("放下后格子表和 id 表应一致")
		quit(1)
		return
	var child_count := manager.get_child_count()
	var structure_count := manager.structures.size()
	var assigned_id := first.id
	var overlap := StructureConfig.bush.instantiate() as Structure
	if manager.add_structure(overlap, cell, true) != StructureManager.AddError.CELL_OCCUPIED:
		push_error("占用格 dry_run 应为 CELL_OCCUPIED")
		quit(1)
		return
	if manager.add_structure(overlap, cell) != StructureManager.AddError.CELL_OCCUPIED:
		push_error("占用格应返回 CELL_OCCUPIED")
		quit(1)
		return
	if overlap.id != 0 or overlap.get_parent() != null:
		push_error("失败时不应分配 id 或挂到树上")
		quit(1)
		return
	if manager.get_child_count() != child_count or manager.structures.size() != structure_count:
		push_error("失败时不应增加子节点或登记")
		quit(1)
		return
	if manager.get_structure_by_id(assigned_id) != first or manager.index_to_structures[cell] != first:
		push_error("原建筑应仍在格子上")
		quit(1)
		return
	var outside := StructureConfig.bush.instantiate() as Structure
	if manager.add_structure(outside, -1) != StructureManager.AddError.CELL_OUT_OF_RANGE:
		push_error("负下标应为 CELL_OUT_OF_RANGE")
		quit(1)
		return
	if manager.add_structure(outside, Game.MAP_CELL_COUNT, true) != StructureManager.AddError.CELL_OUT_OF_RANGE:
		push_error("越界 dry_run 应为 CELL_OUT_OF_RANGE")
		quit(1)
		return
	if outside.get_parent() != null or outside.id != 0:
		push_error("越界不应挂节点或分配 id")
		quit(1)
		return
	quit(0)
