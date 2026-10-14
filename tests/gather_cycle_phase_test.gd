extends SceneTree

## 不依赖场景/addon：校验收成阶段枚举、文案与存档整数值往返。

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/items/item_config.gd")
	load("res://game/characters/ai/character_ai_task_type_id.gd")
	load("res://game/characters/ai/character_ai_task.gd")
	load("res://game/characters/ai/tasks/character_ai_harvest_cycle_task.gd")

	var expected := {
		CharacterAiHarvestCycleTask.Phase.TO_WORKPLACE: "正在去采集者小屋",
		CharacterAiHarvestCycleTask.Phase.IN_WORKPLACE: "正在采集者小屋",
		CharacterAiHarvestCycleTask.Phase.TO_PLANT: "正在采集",
		CharacterAiHarvestCycleTask.Phase.HARVEST: "正在采集",
		CharacterAiHarvestCycleTask.Phase.RETURN_HARVEST: "正在回采集者小屋",
		CharacterAiHarvestCycleTask.Phase.WAIT_PLANT: "正在等待可采集的灌木",
		CharacterAiHarvestCycleTask.Phase.STAY_IN_WORKPLACE: "待在采集者小屋",
		CharacterAiHarvestCycleTask.Phase.TO_WAREHOUSE: "正在把浆果送到仓库",
		CharacterAiHarvestCycleTask.Phase.RETURN_HAUL: "正在回采集者小屋",
	}
	for phase in expected:
		var task := CharacterAiHarvestCycleTask.new({
			CharacterAiHarvestCycleTask.KEY_PHASE: phase,
		})
		var text := task.activity_text()
		if text != expected[phase]:
			push_error("phase %s 文案应为 %s，实际 %s" % [phase, expected[phase], text])
			quit(1)
			return
		var payload: Dictionary = task.serialize()[2]
		var phase_value: int = payload[CharacterAiHarvestCycleTask.KEY_PHASE]
		if phase_value != int(phase):
			push_error("phase %s 序列化应为 %s，实际 %s" % [phase, int(phase), phase_value])
			quit(1)
			return
		var restored := CharacterAiHarvestCycleTask.new({
			CharacterAiHarvestCycleTask.KEY_PHASE: phase_value,
		})
		if restored.activity_text() != text:
			push_error("整数往返后文案变化：%s -> %s" % [text, restored.activity_text()])
			quit(1)
			return

	var legacy := CharacterAiHarvestCycleTask.new({CharacterAiHarvestCycleTask.KEY_PHASE: 2})
	if legacy.activity_text() != "正在采集":
		push_error("旧存档 phase=2 应为正在采集，实际 %s" % legacy.activity_text())
		quit(1)
		return
	if int(CharacterAiHarvestCycleTask.Phase.TO_PLANT) != 2:
		push_error("TO_PLANT 整数值必须保持为 2")
		quit(1)
		return
	if int(CharacterAiHarvestCycleTask.Phase.RETURN_HAUL) != 8:
		push_error("RETURN_HAUL 整数值必须保持为 8")
		quit(1)
		return

	quit(0)
