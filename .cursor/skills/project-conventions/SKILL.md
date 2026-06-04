---
name: project-conventions
description: kingdom2d 项目规范
---

# kingdom2d 项目规范

除**继承场景**外：每个 `.tscn` 根节点脚本为同文件夹同名 `.gd`（外部资源），不用 builtin；场景内其他节点优先 builtin（可访问本场景内任意节点含私有成员），除非有复用可能
[entries/tscn-root-script-same-name-gd.md](entries/tscn-root-script-same-name-gd.md)

每个 `.tscn` 不访问外部；需与外部通讯时由本场景暴露信号，由上层连接
[entries/tscn-signal-boundary.md](entries/tscn-signal-boundary.md)

# 维护此文档

在正文列表中增加一行摘要 + `entries/` 链接，在 `entries/` 下新增对应详述；条目保持短小可检索，不扩成替代官方文档的教程。
