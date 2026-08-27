extends SceneTree

func _init() -> void:
	var ok := true
	ok = _check(ok, StallCellValueCalculator.compute_score(256, 256, 256) == Game.MAP_CELL_COUNT * 2, "same cell max")
	ok = _check(ok, StallCellValueCalculator.compute_score(0, 0, 256) == Game.MAP_CELL_COUNT + (Game.MAP_CELL_COUNT - 256), "left vs banner")
	ok = _check(ok, StallCellValueCalculator.compute_score(255, 250, 256) > StallCellValueCalculator.compute_score(0, 250, 256), "near self and banner beats far")
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1 * 100003 + 7
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1 * 100003 + 7
	ok = _check(ok, rng_a.randf() == rng_b.randf(), "id+day seed stable")
	var stall_count := 0
	for character_id in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = (character_id + 1) * 100003 + 7
		if rng.randf() < 0.5:
			stall_count += 1
	ok = _check(ok, stall_count > 70 and stall_count < 130, "50 percent around half (%s/200)" % stall_count)
	if ok:
		print("Morning market stall tests passed")
		quit(0)
	else:
		print("Morning market stall tests failed")
		quit(1)

func _check(ok: bool, cond: bool, name: String) -> bool:
	if not cond:
		print("FAIL: %s" % name)
		return false
	print("PASS: %s" % name)
	return ok
