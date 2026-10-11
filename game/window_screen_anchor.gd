extends RefCounted
class_name WindowScreenAnchor


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


# 唤出条贴在隐藏前窗口正下方的屏幕底边，宽度跟窗口一致。
static func show_trigger_rect(window_x: int, window_width: int, screen_bottom: int, above_px: int) -> Rect2i:
	return Rect2i(window_x, screen_bottom - above_px, window_width, above_px)
