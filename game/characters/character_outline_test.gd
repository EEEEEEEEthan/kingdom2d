extends SceneTree

func _init() -> void:
	var ok := true
	var character := preload("res://game/characters/character.tscn").instantiate() as Character
	root.add_child(character)
	await process_frame
	ok = _check(ok, character.outline.a == 0.0, "default no outline")
	character.hovered = true
	ok = _check(ok, character.outline == Color.WHITE, "hover outlines")
	character.browser_current = true
	character.hovered = false
	ok = _check(ok, character.outline == Color.WHITE, "browser current keeps outline")
	character.browser_current = false
	ok = _check(ok, character.outline.a == 0.0, "clear when neither")
	character.hovered = true
	character.browser_current = true
	character.hovered = false
	ok = _check(ok, character.outline == Color.WHITE, "hover leave keeps browser current")
	if ok:
		print("Character outline tests passed")
		quit(0)
	else:
		print("Character outline tests failed")
		quit(1)

func _check(ok: bool, cond: bool, name: String) -> bool:
	if not cond:
		print("FAIL: %s" % name)
		return false
	print("PASS: %s" % name)
	return ok
