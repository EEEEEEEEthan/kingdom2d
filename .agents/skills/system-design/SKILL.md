---
name: system-design
description: 维护并引用 Kingdom2D 系统设计文档。在讨论游戏设计、实现玩法/经济/角色/建造等系统、或用户提到设计决策/系统设计时使用；讨论中确认的规则须写入对应子文档并保持更新；发现任何设计冲突时必须立即向用户提出。
---

# Kingdom2D 系统设计

## 使用时机

- 与用户讨论玩法、系统、数值、流程
- 实现新功能前，确认是否已有设计约束
- 用户给出或确认一条设计规则时

## 工作流程

1. **先读**：有未决议题时先看 [open-decisions.md](open-decisions.md)；再按主题打开子文档，避免与设计冲突
2. **讨论**：未决内容只写入 [open-decisions.md](open-decisions.md)，不冒充成规则
3. **冲突**：发现任何设计冲突（新提议 vs 已有规则、子文档之间、设计 vs 代码现状）时，**必须立即向用户提出**，说明冲突双方，暂停写入或实现，待用户裁决
4. **记录**：用户明确确认后，写入对应子文档（子文档正文即已决定的设计，无需标注状态）
5. **联动**：若决策影响代码结构或命名，实现时同步遵守
6. **最美角落**：设计或改机制前对照 [beautiful-corners/](beautiful-corners/README.md)；系统须能展现其中的叙事场景

## 子文档索引

| 主题 | 文件 | 内容 |
|------|------|------|
| **开放决策** | [open-decisions.md](open-decisions.md) | 未决问题优先级与依赖（讨论时先看） |
| 项目概览 | [overview.md](overview.md) | 定位、技术约束、已实现雏形 |
| 经济 / 货币 | [economy.md](economy.md) | 经济单位、获益/预测、市价中位数、流通、早市 |
| 商品估值计算器 | [goods-valuation-calculator.md](goods-valuation-calculator.md) | 个人估值 → 中位数 → 平滑市价 |
| 劳动获益 | [labor-benefit.md](labor-benefit.md) | 职业经济获益：雇佣=佣金，生产类=完成时产出市值 |
| 转职意愿计算器 | [career-change-willingness-calculator.md](career-change-willingness-calculator.md) | 雇佣议价：反推日薪底价（==0） |
| 租意愿计算器 | [rent-willingness-calculator.md](rent-willingness-calculator.md) | 租入/续租意愿、可出租金区间 |
| 建筑估值计算器 | [building-valuation-calculator.md](building-valuation-calculator.md) | 净收入 + 类型保底 + 竣工保护加成 |
| 角色 / 职业 | [characters.md](characters.md) | 建筑工、转职、岗位雇佣、薪酬结算 |
| 生活水平 | [needs.md](needs.md) | 需求阶梯、进度条、租约与换房 |
| 建筑 / 选址 | [structures.md](structures.md) | 占地购地、地基填料、雇工施工、购置拆建 |
| 建筑运营 | [commerce.md](commerce.md) | 税收、床位挂牌租金、运营储备、雇员 |
| 时间与日程 | [time.md](time.md) | 日内四时段、标准上岗时长 |
| 最美角落 | [beautiful-corners/README.md](beautiful-corners/README.md) | 叙事锚点；系统设计须能展现这些场景 |

后续按系统新增子文档（如 `structures.md`、`time.md`），并在此表登记。

## 记录格式

子文档（**最美角落**除外）正文即设计真源，默认均为已决定内容。每条规则使用：

```markdown
### [简短标题]

- **规则**：[一句话核心约束]
- **说明**：[展开、边界、未覆盖处]
```

**最美角落**可使用 `- **状态**：已定` 标注叙事锚点原则；角落内的示例配置仍为非平衡定案。

## 维护原则

- **冲突优先**：不得忽略、淡化或自行调和设计冲突；未获用户确认前，不得悄悄写入子文档。每次修改之前必须检查与既有设计的冲突
- 聊天里的口头约定未写入文档则视为未固化
- 废止规则时在原文标「已废止」，勿静默删除
- 保持简洁，只记对实现有约束力的内容
