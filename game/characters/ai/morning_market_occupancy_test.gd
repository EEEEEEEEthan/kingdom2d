extends SceneTree

func _init() -> void:
	var ok := true
	var manager := CharacterManager.new()
	root.add_child(manager)
	var a := _make_character(manager, 1, 1)
	var b := _make_character(manager, 2, 1)
	ok = _check(ok, manager.try_claim_stall(10, 1, 1), "first claim")
	ok = _check(ok, not manager.try_claim_stall(10, 2, 1), "second character blocked")
	ok = _check(ok, manager.is_stall_claimed_by_other(10, 2), "claimed by other")
	ok = _check(ok, not manager.is_stall_claimed_by_other(10, 1), "owner not other")
	ok = _check(ok, manager.get_live_stall_cell_index_for(1, 1) == 10, "owner cell")
	var live_cells := manager.get_live_stall_cell_indices()
	ok = _check(ok, live_cells.size() == 1 and live_cells[0] == 10, "live list")
	a.get_node("%AiBrain").behavior_token += 1
	ok = _check(ok, not manager.is_stall_claimed_by_other(10, 2), "dead after token bump")
	ok = _check(ok, manager.try_claim_stall(10, 2, 1), "reclaim after interrupt")
	if ok:
		print("Morning market occupancy tests passed")
	else:
		print("Morning market occupancy tests failed")
	a.queue_free()
	b.queue_free()
	manager.queue_free()
	quit(0 if ok else 1)

func _make_character(manager: CharacterManager, character_id: int, token: int) -> Character:
	var character: Character = load("res://game/characters/character.tscn").instantiate()
	character.id = character_id
	manager.add_child(character)
	manager.characters[character_id] = character
	var brain: Node = character.get_node("%AiBrain")
	brain.behavior_token = token
	brain.set_process(false)
	return character

func _check(ok: bool, cond: bool, name: String) -> bool:
	if not cond:
		print("FAIL: %s" % name)
		return false
	print("PASS: %s" % name)
	return ok
