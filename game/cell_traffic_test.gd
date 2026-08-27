extends SceneTree

func _init() -> void:
	var failures := 0
	failures += _test_enter_and_rollover()
	failures += _test_hottest_cell()
	failures += _test_first_day_uses_today()
	failures += _test_zero_counts_skip_left_edge()
	failures += _test_serialize()
	failures += _test_seed_split()
	if failures > 0:
		printerr("cell_traffic tests failed: %s" % failures)
	else:
		print("cell_traffic tests passed")
	quit(failures)


func _test_enter_and_rollover() -> int:
	var traffic := CellTraffic.new()
	traffic._sync_day(1)
	traffic._note_enter(1, 10)
	traffic._note_enter(1, 10)
	traffic._note_enter(1, 11)
	traffic._note_enter(1, 10)
	if traffic._today[10] != 2 or traffic._today[11] != 1:
		printerr("enter count 当天统计错误")
		return 1
	traffic._sync_day(2)
	if traffic._yesterday[10] != 2 or traffic._today[10] != 0:
		printerr("跨天滚动错误")
		return 1
	traffic._note_enter(1, 10)
	if traffic._today[10] != 0:
		printerr("跨天仍停在原地不应再计入进入")
		return 1
	return 0


func _test_hottest_cell() -> int:
	var traffic := CellTraffic.new()
	var manager := CharacterManager.new()
	traffic._sync_day(1)
	traffic._note_enter(1, 8)
	traffic._note_enter(2, 8)
	traffic._note_enter(1, 3)
	traffic._sync_day(2)
	var hottest := traffic.pick_hottest_unclaimed_cell(manager)
	manager.free()
	if hottest != 8:
		printerr("最热格子应为 8，实际 %s" % hottest)
		return 1
	return 0


func _test_first_day_uses_today() -> int:
	var traffic := CellTraffic.new()
	var manager := CharacterManager.new()
	traffic._sync_day(7)
	traffic._note_enter(1, 256)
	traffic._note_enter(2, 256)
	var hottest := traffic.pick_hottest_unclaimed_cell(manager)
	manager.free()
	if hottest != 256:
		printerr("无昨天数据时应使用当天进格，期望 256 实际 %s" % hottest)
		return 1
	return 0


func _test_zero_counts_skip_left_edge() -> int:
	var traffic := CellTraffic.new()
	var manager := CharacterManager.new()
	traffic._sync_day(1)
	var hottest := traffic.pick_hottest_unclaimed_cell(manager)
	manager.free()
	if hottest != -1:
		printerr("零进格不应落到最左格，实际 %s" % hottest)
		return 1
	return 0


func _test_serialize() -> int:
	var traffic := CellTraffic.new()
	traffic._sync_day(4)
	traffic._note_enter(9, 20)
	var restored := CellTraffic.new()
	restored.deserialize(traffic.serialize())
	if restored._day_index != 4 or restored._today[20] != 1:
		printerr("序列化往返错误")
		return 1
	return 0


func _test_seed_split() -> int:
	var stall_count := 0
	var visit_count := 0
	for character_id in range(1, 9):
		var rng := RandomNumberGenerator.new()
		rng.seed = character_id + 7
		if rng.randf() < 0.5:
			stall_count += 1
		else:
			visit_count += 1
	if stall_count == 0 or visit_count == 0:
		printerr("id+天数种子未同时覆盖摆摊与逛摊 stall=%s visit=%s" % [stall_count, visit_count])
		return 1
	return 0
