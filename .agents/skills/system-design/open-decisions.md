# 开放决策（优先级）

> 尚未敲定的设计问题汇总。子文档正文只记**已定**规则；本节按**阻塞关系**排序，供讨论时优先裁决。
>
> **用法**：从上往下或按优先级挑一条，讨论确认后写入对应子文档，再从此处删减。

---

## P0 — 闭环缺口（无则难以跑通模拟）

（当前无 P0 未决项。）

---

## P1 — 规则歧义（已定机制内的洞或冲突）

### D09 同一角色自由职业与雇佣职业是否互斥

- **写入目标**：[characters.md](characters.md)
- **问题**：受雇期间是否仍算某自由职业、能否日常转职、挖墙脚后旧岗位如何处理——文档隐含互斥但未写明。
- **阻塞**：转职日更、劳动获益分段、UI 展示「当前职业」。

---

## P2 — 实现期 / polish

| # | 议题 | 写入目标 | 备注 |
|---|------|----------|------|
| D10 | 受雇建筑工能否同时参与多处施工 | structures.md | 与「责任方仅一处工地」不同维度 |
| D12 | 雇员薪酬结算时刻：午夜还是早市等 | characters.md + time.md? | 与 D05 联动 |
| D13 | 建筑净收入收支事件统计口径 | building-valuation-calculator.md + commerce.md | |
| D14 | 净收入映射、类型保底峰值、竣工加成峰值、未竣工工地计价、刷新周期 | building-valuation-calculator.md | 竣工加成递减已定 |
| D15 | 非整日劳动、多商品职业 | labor-benefit.md | 建筑被动产出**不计入**雇员产出市值（已定，见 commerce.md） |
| D16 | 转职意愿计算器 Context 配置 vs 单表驱动 | career-change-willingness-calculator.md | 实现向 |
| D17 | 租意愿计算器因素与等级租金区间聚合 | rent-willingness-calculator.md | |
| D18 | 实现层命名与统计缓存 | 各计算器文档 | 实现向 |
| D19 | 角色死亡时货币/资源归属（工地清场已定，见 structures「工地异常」） | economy.md + characters.md | 死亡首版不实现 |
| D20 | 拆毁零成本是否导致「只买格不经营」主导策略 | structures.md / economy.md | 平衡观察，可后验调 |

---

## P3 — 经济与平衡风险（观察项，裁决时可一并记入 skill）

| # | 风险 | 相关文档 |
|---|------|----------|
| W01 | 领主 80% 货币不计流通 → 刻意压低流通量；领主只进不出时通胀偏弱 | economy.md |
| W02 | 浆果过剩 → 市价崩 → 转职僵局；**领主破局**为预期最美角落 | labor-benefit.md, goods-valuation-calculator.md, [berry-glut-career-dead-end.md](beautiful-corners/berry-glut-career-dead-end.md) |
| W03 | 转职权重和 > 100 时空白为 0，是否归一化未定 → 转职频率波动 | labor-benefit.md |
| W04 | 角色详情与转职意愿计算器「平均劳动获益」可用不同统计窗口 | labor-benefit.md |

---

## 建议讨论顺序

```
D13/D14 估值口径
     ↓
D09 职业互斥 → P2 表内各项
```

---

## 依赖关系（简图）

```
资源标签 ─→ 需求 / 预期库存；市价按品种
商品估值计算器 ─→ 众人中位数 ─→ 平滑市价 ─→ 早市 / 产出市值 ─→ 转职分数
旅行商人 ─→ 场内货币总量 / 估值样本（同常驻角色，不含领主）
浆果过剩（最美角落）─→ 领主审批 / 税收 / 早市等手段破局

建筑净收入（租金+营业−税−薪酬）─→ 建筑估值 ─→ 占格成交价
生活水平 ─→ 自建 / 租床 / 【食物】预期库存
占格清场 ─→ 土地归领主（无回购）

建筑估值 ─→ luxury-housing / 购置比价
领主审批流程 ─→ multi-tile-workshop / berry-glut
```

---

## 关联

- 索引入口：[SKILL.md](SKILL.md)
- 叙事检验：[beautiful-corners/README.md](beautiful-corners/README.md)
