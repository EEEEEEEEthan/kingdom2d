# 开放决策（优先级）

> 尚未敲定的设计问题汇总。子文档正文只记**已定**规则；本节按**阻塞关系**排序，供讨论时优先裁决。
>
> **用法**：从上往下或按优先级挑一条，讨论确认后写入对应子文档，再从此处删减。

---

## P0 — 闭环缺口（无则难以跑通模拟）

（当前无 P0 未决项。）

---

## P1 — 规则歧义（已定机制内的洞或冲突）

| # | 议题 | 写入目标 | 备注 |
|---|------|----------|------|
| D23 | **毛利创值 vs 净运营**：建筑创值=售品+租金（不含税/薪酬/原料），但运营储备、建造可负担看净支出；**商业投资盈利判定**、**日薪上限**是否改看净利或「创值−运营成本」 | economy.md + commerce.md + structures.md + building-valuation-calculator.md | 创值模型重构后暴露；毛利可能系统性高估可雇性与投资价值；自租已计入创值/估值/日薪上限（D24 已裁） |

---

## P2 — 实现期 / polish

| # | 议题 | 写入目标 | 备注 |
|---|------|----------|------|
| D13 | 建筑账本收支事件统计口径（与创值售品/床位租金子集区分） | building-valuation-calculator.md + commerce.md | |
| D21 | 领主与场内角色的市场交易渠道（领主不参与早市；阈值调节已定） | economy.md | 与 lord-circulation / berry-glut 破局手段相关 |
| D14 | 创值映射、类型保底峰值、竣工加成峰值、未竣工工地计价、刷新周期；**创值预测**（预期可售出、角色雇主预测） | building-valuation-calculator.md + economy.md | 竣工加成递减已定；新建筑/无样本职业/雇工上限回退均依赖预测 |
| D25 | 建筑创值「**实际出售商品**」是否含**窗口内服务成交**（酒馆服务、澡堂服务等不可代摊产出） | commerce.md + economy.md | 措辞偏实物；漏计则酒馆主收入不进创值 |
| D27 | **职业创值**该职业**人数为 0** 时：全场中位数回退 vs **创值预测** vs 配置缺省 | value-creation.md + career-change-willingness-calculator.md | 全场仅拾荒者时，伐木工等会误用拾荒者中位数 |
| D15 | 非整日劳动、多商品职业 | value-creation.md | 建筑被动产出**不计入**雇员产出市值（已定，见 commerce.md） |
| D16 | 转职意愿计算器 Context 配置 vs 单表驱动 | career-change-willingness-calculator.md | 实现向 |
| D17 | 租意愿计算器因素与等级租金区间聚合 | rent-willingness-calculator.md | |
| D18 | 实现层命名与统计缓存 | 各计算器文档 | 实现向 |
| D19 | 角色死亡时货币/资源归属（工地清场已定，见 structures「工地异常」） | economy.md + characters.md | 死亡首版不实现 |
| D20 | 拆毁零成本是否导致「只买格不经营」主导策略 | structures.md / economy.md | 平衡观察，可后验调；与 D24 自租抬估值联动 |

---

## P3 — 经济与平衡风险（观察项，裁决时可一并记入 skill）

| # | 风险 | 相关文档 |
|---|------|----------|
| W01 | （已升格最美角落）领主持币与流通口径 → **领主货币政策** | [lord-circulation-control.md](beautiful-corners/lord-circulation-control.md), economy.md |
| W02 | 浆果过剩 → 市价崩 → 转职僵局；**领主破局**为预期最美角落 | value-creation.md, goods-valuation-calculator.md, [berry-glut-career-dead-end.md](beautiful-corners/berry-glut-career-dead-end.md) |
| W03 | 转职权重和 > 100 时空白为 0，是否归一化未定 → 转职频率波动 | value-creation.md |
| W04 | 角色详情与转职意愿计算器「个体创值 / 职业创值」可用不同统计窗口 | value-creation.md |
| W05 | **租意愿** affordability 看现金结余，**创值**含非现金产出（自食浆果）→ 创值高仍可能付不起租 | rent-willingness-calculator.md, value-creation.md |
| W06 | 建筑**库存积压**：生产记入生产行为记录，创值仅售出/收租 → 滞销期创值归零，预测与保底估值权重过大 | commerce.md, economy.md, building-valuation-calculator.md |

---

## 建议讨论顺序

```
D23 / D24（毛利创值与自租估值）
     ↓
D25–D27 + D13/D14
     ↓
P2 表内其余项
```

---

## 依赖关系（简图）

```
资源标签 ─→ 需求 / 预期库存；市价按品种
商品估值计算器 ─→ 众人中位数 ─→ 平滑市价 ─→ 早市 / 产出市值 ─→ 转职分数
旅行商人 ─→ 场内货币总量 / 估值样本（同常驻角色，不含领主）
领主（红小人）─→ 审批 / 库存阈值 / 只进不出；市场交易见 D21
浆果过剩（最美角落）─→ 领主审批 / 税收 / 阈值释货等手段破局

0:00 批处理：薪酬 → 市价 → 日常转职；12:00 租意愿

建筑创值（售品+床位租金，含自租）─→ 建筑估值 ─→ 占格成交价；账本净收支 ─→ 运营储备
生活水平 ─→ 自建 / 租床 / 【食物】预期库存
占格清场 ─→ 土地归领主（无回购）

建筑估值 ─→ luxury-housing / 购置比价
领主审批流程 ─→ multi-tile-workshop / berry-glut
```

---

## 关联

- 索引入口：[SKILL.md](SKILL.md)
- 叙事检验：[beautiful-corners/README.md](beautiful-corners/README.md)
