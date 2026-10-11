extends RefCounted


static func clamp_x_to_screen(x: int, screen_x: int, screen_width: int, window_width: int) -> int:
	if screen_width <= window_width:
		return screen_x
	return clampi(x, screen_x, screen_x + screen_width - window_width)


# 贴左或贴右时改宽度继续贴那一侧。两边都贴（铺满）保持贴左。否则保持中心，再夹回屏幕内。
static func anchored_x_on_screen(
	old_x: int,
	old_width: int,
	new_width: int,
	screen_x: int,
	screen_width: int,
) -> int:
	var screen_right := screen_x + screen_width
	var x := old_x
	if old_x <= screen_x:
		x = screen_x
	elif old_x + old_width >= screen_right:
		x = screen_right - new_width
	else:
		var center_x := float(old_x) + float(old_width) * 0.5
		x = int(round(center_x - float(new_width) * 0.5))
	return clamp_x_to_screen(x, screen_x, screen_width, new_width)
