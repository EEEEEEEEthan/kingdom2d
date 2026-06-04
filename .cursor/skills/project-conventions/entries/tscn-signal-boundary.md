# 场景边界：不访问外部，用信号通讯

## 规则

每个 `.tscn`（及其脚本）应视为封闭单元：**不**在场景内部直接依赖或操作**场景树以外**的节点或其它 `.tscn` 实例。需要与父级、兄弟场景交互时，**在本场景根上声明信号**（必要时配合少量 `@export` 配置），由 **实例化方或上层** 在编辑器或代码里 `connect`。**Autoload**（含 `static` 与单例实例）可直接访问。

## 禁止（场景内部）

- `get_node("/root/...")`、`get_tree().root.get_node(...)` 等方式抓取场景外节点。
- 硬编码其它场景的路径并 `get_node` 到已挂载的实例。
- 在子脚本里用 `get_parent()` 链穿透到本场景之外的节点。

## 正确做法

场景内处理自身子树与导出属性；读写在 **Autoload** 可直接进行；与**其它场景/节点**的协作用 **信号** 或 **暴露可被上层赋值的属性**。

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
# ❌ 在 HUD 里直接操作 Main 下的 ControlWindow（场景树外节点）
func _on_settings_pressed() -> void:
	get_node("/root/Main/ControlWindow").popup_centered()
```

应改为 `signal control_window_open_requested`，由上层连接后打开窗口。

```gdscript
# ✅ 通过 Autoload 读配置或写存档（允许）
func _ready() -> void:
	scale = Settings.display_scale

func _on_apply_pressed() -> void:
	Settings.save()
```

## 允许（场景内部）

- 访问本场景子树：`%NodeName`、`owner`、同场景 `get_node`。
- 使用引擎通用 API（`DisplayServer`、`Input` 等）。
- 访问 **Autoload**：单例实例的成员/方法（如 `Settings.save()`、`Game.xxx()`）与 **static** 方法均可。

## 为什么

- 场景可单独打开、测试与复用。
- 依赖方向清晰：外层组装内层，内层不反向耦合外层。
- 重构节点树时，只需改连接处，不必改多个 tscn 脚本。
