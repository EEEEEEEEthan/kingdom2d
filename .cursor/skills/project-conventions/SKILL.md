---
name: project-conventions
description: kingdom2d 项目规范
---

# kingdom2d 项目规范

除**继承场景**外：根脚本为同文件夹同名 `.gd`（尽量薄，作对外边界）；具体功能在 tscn 内子节点 builtin 实现（可访问场景内含私有成员），除非有复用可能
[entries/tscn-root-script-same-name-gd.md](entries/tscn-root-script-same-name-gd.md)

每个 `.tscn` 不访问场景树外节点/其它 tscn；与父级等通讯用信号；Autoload 可直接访问
[entries/tscn-signal-boundary.md](entries/tscn-signal-boundary.md)

场景根 `.gd` 不写仅为子节点信号中转的 `_on_*`；子节点 builtin 用 `owner` 调根上 API，场景外连 public 方法
[entries/tscn-root-no-child-relay-handlers.md](entries/tscn-root-no-child-relay-handlers.md)

# 维护此文档

在正文列表中增加一行摘要 + `entries/` 链接，在 `entries/` 下新增对应详述；条目保持短小可检索，不扩成替代官方文档的教程。
