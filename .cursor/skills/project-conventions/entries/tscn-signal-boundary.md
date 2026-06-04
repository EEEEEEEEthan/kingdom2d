# 场景边界：不访问外部，用信号通讯

## 规则

每个 `.tscn`（及其脚本）应视为封闭单元：**不**在场景内部直接依赖或操作场景树以外的对象。需要与父级、兄弟场景、Autoload 或其它系统交互时，**在本场景根上声明信号**（必要时配合少量 `@export` 配置），由 **实例化方或上层** 在编辑器或代码里 `connect`。

## 禁止（场景内部）

- `get_node("/root/...")`、`get_tree().root.get_node(...)` 等方式抓取场景外节点。
- 直接调用 Autoload 单例的业务方法（如 `Game.xxx()`、`Settings.save()`），除非该 Autoload 是纯工具且无项目状态耦合——仍优先信号上抛。
- 硬编码其它场景的路径并 `get_node` 到已挂载的实例。
- 在子脚本里用 `get_parent()` 链穿透到本场景之外的节点。

## 正确做法

场景内只处理自身子树与导出属性；对外只 **发信号** 或 **暴露可被上层赋值的属性**。

```gdscript
# game_window.gd（场景根）
signal control_window_open_requested
signal quit_requested

func _on_settings_button_pressed() -> void:
	control_window_open_requested.emit()
```

上层（如 `main.gd` 或 `main.tscn` 里的连接）负责接线：

```gdscript
%GameWindow.control_window_open_requested.connect(_open_control_window)
%GameWindow.quit_requested.connect(request_quit)
```

## 错误示例

```gdscript
# ❌ 在 game_window.gd 内直接打开控制窗
func _on_settings_pressed() -> void:
	get_node("/root/Main/ControlWindow").show()
```

```gdscript
# ❌ 在 HUD 场景里直接改 Game 单例状态
func _on_build_clicked() -> void:
	Game.current_mode = Game.Mode.BUILD
```

应改为 `signal build_mode_requested` 等，由 `main` 或 `game` 层连接后改状态。

## 允许（场景内部）

- 访问本场景子树：`%NodeName`、`owner`、同场景 `get_node`。
- 使用引擎通用 API（`DisplayServer`、`Input` 等）且不绑定其它业务场景时。

## 为什么

- 场景可单独打开、测试与复用。
- 依赖方向清晰：外层组装内层，内层不反向耦合外层。
- 重构节点树或替换 Autoload 时，只需改连接处，不必改多个 tscn 脚本。
