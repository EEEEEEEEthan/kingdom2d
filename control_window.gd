extends Window

signal reset_game_requested


func _ready() -> void:
	visible = false
	# 按下窗口顶部时交给窗口管理器开始拖。系统标题栏本身不进游戏输入。
	var bar := Button.new()
	bar.name = "TitleDrag"
	bar.text = ""
	bar.focus_mode = Control.FOCUS_NONE
	bar.flat = true
	bar.custom_minimum_size = Vector2(0, 14)
	var empty := StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("normal", empty)
	bar.add_theme_stylebox_override("hover", empty)
	bar.add_theme_stylebox_override("pressed", empty)
	bar.add_theme_stylebox_override("focus", empty)
	bar.button_down.connect(func() -> void:
		DisplayServer.window_start_drag(get_window_id())
	)
	var box := get_node_or_null("VBoxContainer")
	if box:
		box.add_child(bar)
		box.move_child(bar, 0)


func open_near_mouse() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	# 无边框弹层客户区才画得出来。标题栏用系统装饰补上，不走 borderless 属性，避免把已经画好的帧清掉。
	borderless = true
	position = pos
	show()
	_show_system_title_bar()
	_sync_stacking()
	grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_stacking()


func _sync_stacking() -> void:
	var game := get_parent() as Window
	if game == null:
		return
	# 游戏条一直置顶，会盖住设置窗。设置打开时先取消游戏条置顶，再把设置窗抬到最前。
	# 不走 Godot 的置顶标记，那个会和 transient 打架。只把游戏条的置顶拿掉，外框叠放交给 X11。
	game.always_on_top = not visible


func _show_system_title_bar() -> void:
	if DisplayServer.get_name() != "X11":
		return
	var native := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, get_window_id())
	if native == 0:
		return
	# 游戏条是 UTILITY。设置窗若是 NORMAL，会被它盖住。保持 UTILITY，补上标题栏，再把外框抬到游戏条上面。
	var script := """
import ctypes, sys
wid = int(sys.argv[1])
game = int(sys.argv[2]) if len(sys.argv) > 2 else 0
x11 = ctypes.cdll.LoadLibrary('libX11.so.6')
dpy = x11.XOpenDisplay(None)
motif = x11.XInternAtom(dpy, b'_MOTIF_WM_HINTS', False)
wtype = x11.XInternAtom(dpy, b'_NET_WM_WINDOW_TYPE', False)
utility = x11.XInternAtom(dpy, b'_NET_WM_WINDOW_TYPE_UTILITY', False)
transient = x11.XInternAtom(dpy, b'WM_TRANSIENT_FOR', False)
state = x11.XInternAtom(dpy, b'_NET_WM_STATE', False)
above = x11.XInternAtom(dpy, b'_NET_WM_STATE_ABOVE', False)
hints = (ctypes.c_ulong * 5)(2, 0, 1, 0, 0)
x11.XChangeProperty(dpy, wid, motif, 6, 32, 0, ctypes.cast(hints, ctypes.c_void_p), 5)
kind = ctypes.c_ulong(utility)
x11.XChangeProperty(dpy, wid, wtype, 4, 32, 0, ctypes.cast(ctypes.byref(kind), ctypes.c_void_p), 1)
x11.XDeleteProperty(dpy, wid, transient)
above_atom = ctypes.c_ulong(above)
x11.XChangeProperty(dpy, wid, state, 4, 32, 0, ctypes.cast(ctypes.byref(above_atom), ctypes.c_void_p), 1)
x11.XUnmapWindow(dpy, wid)
x11.XFlush(dpy)
x11.XMapWindow(dpy, wid)
root = ctypes.c_ulong(); parent = ctypes.c_ulong(); children = ctypes.c_void_p(); nchildren = ctypes.c_uint()
x11.XQueryTree(dpy, wid, ctypes.byref(root), ctypes.byref(parent), ctypes.byref(children), ctypes.byref(nchildren))
frame = parent.value or wid
if game:
    order = (ctypes.c_ulong * 2)(frame, game)
    x11.XRestackWindows(dpy, order, 2)
else:
    x11.XRaiseWindow(dpy, frame)
x11.XFlush(dpy)
"""
	var game := get_parent() as Window
	var game_native := 0
	if game:
		game_native = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, game.get_window_id())
	OS.execute("python3", ["-c", script, str(native), str(game_native)])
