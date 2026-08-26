# 同名 .gd 根脚本只做转发，具体逻辑下沉子节点 builtin

## 踩坑

把所有功能（AI tick、idle wander 调度、序列化细节等）全写在 `foo.gd` 里，而 `foo.tscn` 的子节点没有 builtin 脚本。

## 正确做法

- `foo.gd`（根脚本）尽量薄：只保留 `class_name`、`signal`、`@export`、对外 public 方法。
- 具体逻辑写在 `foo.tscn` 内子节点的 builtin 脚本中，通过 `owner` 调用根脚本的 public API。
- 根脚本需要访问子节点 builtin 的功能时，用 `%UniqueName` 转发调用。

## 反面案例

`character.gd` 把 AI tick、`_schedule_idle_wander`、`_pick_idle_wander_target_world_x`、`ai_task_stack` 管理全部堆在根脚本；重构后 AI 逻辑移入 `AiBrain` 子节点 builtin，`character.gd` 只剩 `advance_toward_world_x`、`deserialize`（通过 `%AiBrain` 分发）、`serialize`。

## 注意

子节点 builtin 用 `owner` 访问场景根，不要用 `get_parent()`。
