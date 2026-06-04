# tscn 脚本放置：根节点外部 .gd，子节点优先 builtin

## 规则

1. **根节点（场景直接脚本）**：`foo.tscn` 的根脚本必须是同目录下的 `foo.gd`，通过 `[ext_resource]` 引用，**不要**用 `[sub_resource type="GDScript"]`（builtin）。
2. **同名 `.gd` 尽量薄**：`foo.gd` 只保留场景对外边界（`signal`、`@export`、少量 public 方法、必要的根级生命周期）；具体交互、布局、子控件逻辑写在 tscn 内各节点的 **builtin** 里。
3. **场景内其他节点**：脚本尽可能写在 tscn 内的 builtin（`sub_resource`），除非该逻辑可能在多个场景/节点间复用。

## 子节点为何优先 builtin

同一场景内的 builtin 脚本视为场景**内部实现**：可通过 `owner`、`%UniqueName`、`get_node` 等访问本 `.tscn` 内任意节点，包括场景根或其它节点上标为**私有**的成员（`_` 前缀变量/方法、`@export` 属性、未在文档中对外承诺的 API）。

因此：

- **根脚本**（外部 `.gd`）越薄越好：声明信号与对外 API，复杂实现下沉到子节点 builtin。
- **子节点 builtin**承担本场景绝大部分逻辑，可直接耦合根上的 `_` 实现，无需为「给子脚本用」再拆一层 public 包装。

若逻辑要跨场景复用，才拆成独立 `.gd`；此时按普通类边界访问，不应依赖其它场景的私有成员。

4. **例外**：**继承场景**（根节点实例化另一 `.tscn` 的变体）可在根上用 builtin 扩展基类逻辑，不要求每个变体都有独立同名 `.gd`。

## 正确示例

```
game/
  game_window.tscn   → 根脚本 res://game/game_window.gd
  game_window.gd
```

tscn 片段：

```ini
[ext_resource type="Script" path="res://game/game_window.gd" id="1_script"]

[node name="GameWindow" type="Window"]
script = ExtResource("1_script")
```

子节点（仅本场景用、无复用）用 builtin：

```ini
[sub_resource type="GDScript" id="GDScript_child"]
script/source = "extends Control
func _ready() -> void:
	pass
"

[node name="ChildPanel" type="Control" parent="."]
script = SubResource("GDScript_child")
```

薄根脚本 + builtin 分工（示意）：

```gdscript
# main.gd — 仅边界
extends Node

signal quit_confirmed

func request_quit() -> void:
	%QuitConfirmDialog.visible = true
```

```gdscript
# main.tscn 内 QuitConfirmDialog 的 builtin — 定位、显隐等细节
extends ConfirmationDialog

func _ready() -> void:
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_place_near_global_mouse()
# ...
```

## 错误示例

- `game_window.tscn` 根节点使用 `sub_resource` 内联整段脚本，而同目录没有 `game_window.gd`（非继承场景）。
- `game_window.gd` 数百行，拖拽/布局/按钮响应全堆在根脚本，而本可挂在子节点 builtin 上。
- 仅在一个 tscn 里用一次的小逻辑却拆成独立 `.gd` 文件（无复用价值时增加文件噪音）。

## 继承场景例外说明

根节点通过 `[ext_resource type="PackedScene"]` 实例化基场景、再在根上挂 builtin 脚本的变体（如 `oak.tscn` 继承 `base_structure.tscn` 并 `extends Structure`），**不**强制 `oak.gd` 等同名文件。

## 何时拆成外部 .gd

- 该脚本是 **tscn 根节点** 的直接脚本（且不是继承场景的变体根）。
- 子节点逻辑需要在 **多个场景** 或 **多个节点** 上复用时，再提取为共享 `.gd`。
