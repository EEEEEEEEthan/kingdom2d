---
name: design-issue-resolver
description: 逐条裁决 Kingdom2D 待办设计问题。当用户想推进开放决策、清除 open-decisions.md 中的未决项、或实现功能前敲定设计口径时使用；把当前最应解决的问题用中文问给用户，答案归档到对应子文档后再问下一个。
---

# 设计问题逐条裁决

围绕 [open-decisions.md](../system-design/open-decisions.md) 的引导式问答循环：**一次只问一个**当前最应解决的问题，用户回答后**归档**，再问下一个。

## 使用时机

- 用户说「推进设计问题 / 裁决开放决策 / 清 open-decisions」
- 开始实现受设计约束的功能前，先确认相关未决项已裁
- 用户希望以「一问一答」方式逐条敲定设计

## 前置

- 本技能是 [system-design](../system-design/SKILL.md) 的**补充流程**：使用前先按 system-design 加载其子文档与记录规则
- 问题来源：`.agents/skills/system-design/open-decisions.md`（已定规则在对应子文档）

## 工作流程

1. **读**：打开 [open-decisions.md](../system-design/open-decisions.md)，按其 **P0 → P1 → P2** 优先级与「建议讨论顺序」确定当前**最应解决**的**一个**问题
2. **问**：用中文向用户提出这一个问题，需说明：
   - **现状**：什么没定、牵涉哪些子文档（列文件名）
   - **冲突双方**：若属规则冲突，说清冲突双方，请用户裁决
   - **可选方向**：如可能给出你推荐的一个选项（可简短）
   - 一次只问一个；**不抛清单**
3. **归档**：用户回答后，按 system-design 记录格式写入对应子文档；已解决项从 open-decisions.md **删除**；未定部分保留
4. **检查冲突**：归档前对照既有设计；发现冲突（新提议 vs 已有规则、子文档之间）必须**立即提出并暂停**，待用户裁决
5. **提交并推送**：每次归档完成后 `git commit -m "<中文消息>" --author="claude and ethan <ethan.tang@coconutislandstudio.com>"` 并 `git push`
6. **问下一个**：重复步骤 1，直至用户叫停

## 规则

- **一次一个问题**；归档完成才问下一个
- 未获用户确认**不写入**子文档
- 确认的口头约定才固化；未决内容只留在 open-decisions.md
- 提交必须**每次归档后自动执行**，不等用户吩咐：`git commit -m "<中文消息>" --author="claude and ethan <ethan.tang@coconutislandstudio.com>"`，随后 `git push`
