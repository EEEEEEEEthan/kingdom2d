extends RefCounted
class_name CharacterActivity

static func describe(character: Character) -> String:
	if character.indoors and CharacterSchedule.is_sleep_period(character):
		return "正在睡觉"
	if character.indoors:
		return "正在家里"
	var top := character.ai_task_stack.peek()
	if top == null:
		return "正在发呆"
	if top is CharacterAiMoveToWorldXTask and character.ai_task_stack.has_task(CharacterAiEnterHomeTask):
		return "正在回家"
	var line := top.activity_text()
	if line.is_empty():
		return "正在发呆"
	return line
