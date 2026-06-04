# 根脚本：子节点事件用 owner，不用 _on 中转

## 规则

场景根的外部 `.gd` **不要**写仅用于响应**本场景子节点**信号的 `_on_*` 方法（在 tscn 里把子节点信号连到根上的典型写法）。

子节点（含 builtin）在收到自身 UI/子树信号后，直接调用根上的对外 API，例如：

```gdscript
owner.reset_camera()
owner.control_window_open_requested.emit()
owner.game.start_build_placement(structure_config)
```

根脚本保留：`signal`、`@export`、供**场景外**连接的 **具名 public 方法**（不要用 `_on_*` 命名）。

子节点若只需 **emit 根上已有 signal**，在 builtin 里 `owner.xxx.emit()`，**不要**在根上再包一层 `func confirm_xxx(): xxx.emit()`。

## 场景外事件

其它场景、上层组装（`main.tscn` 连接）或 Autoload 信号，应连到根上的 **public 方法**，而不是 `_on_xxx_pressed` 式命名：

```gdscript
# game_hud.gd
func reset_camera() -> void:
	game.reset_camera()
```

```ini
# 上层需要重置镜头时
[connection signal="..." from="..." to="GameHud" method="reset_camera"]
```

## 同场景内子场景实例

子场景根发出的信号由**父场景**在 tscn 或 `_ready` 里组装（`connect` 到父根 signal / public 方法），父根同样不为「子场景信号 → 再 emit」单独写 `_on_game_hud_*`；可用 `child_signal.connect(parent_signal.emit)` 等。

## 允许留在根上的 _on_*

- 信号来自**根节点自身**（脚本 `extends` 的节点类型自带的信号，如 `StatusIndicator.pressed` 写在 `tray.gd`）。
- 来自 **Autoload / 引擎 / 场景外** 且根脚本是合理落点的连接（仍优先用具名方法表达意图，避免 `_on_foo_pressed` 仅转发子按钮）。

## 错误示例

```gdscript
# game_hud.gd — ❌ 仅为 PopupMenu / Button 中转
func _on_reset_camera_pressed() -> void:
	game.reset_camera()

func _on_popup_quit_requested() -> void:
	quit_requested.emit()
```

```ini
# ❌ 子按钮信号连到场景根
[connection signal="pressed" from="ResetCamera" to="." method="_on_reset_camera_pressed"]
```

## 正确示例

```gdscript
# game_hud.tscn 内 ResetCamera 的 builtin
extends Button

func _on_pressed() -> void:
	owner.reset_camera()
```

```gdscript
# game_hud.gd — 对外 API
func reset_camera() -> void:
	game.reset_camera()
```
