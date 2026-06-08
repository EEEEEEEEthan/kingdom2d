# 开放决策（优先级）

> 尚未敲定的设计问题汇总。子文档正文只记**已定**规则；本节按**阻塞关系**排序，供讨论时优先裁决。
>
> 格式：`[P0/P1/P2]` 优先级 · 来源文档 · 问题 · 阻塞什么

---

## P2 — 边界与 polish

| # | 问题 | 来源 |
|---|------|------|
| X9 | 各建筑类型邻域/地形规则表 | [structures.md](structures.md) |
| X10 | 待办队列 UI 节点、校验失败反馈文案 | [structures.md](structures.md) |
| X11 | 劳动获益 UI / 平衡用途 | [labor-benefit.md](labor-benefit.md) |
| X12 | 实现层命名与统计缓存 | 各计算器文档 |
| X13 | 受雇建筑工是否可同时参与多处施工 | [structures.md](structures.md) |
| X14 | 领主回购后建筑/土地处置与购回 UI | [structures.md](structures.md) |
| X15 | 雇员薪酬结算时刻（午夜/早市等） | [characters.md](characters.md) |
| X16 | 商业净收入收支事件统计口径 | [building-valuation-calculator.md](building-valuation-calculator.md) |
| X17 | 建筑估值金额映射、未竣工工地计价、刷新周期、购地价是否纳入 | [building-valuation-calculator.md](building-valuation-calculator.md) |
| X18 | 非整日劳动、多商品职业、建筑被动产出是否计入产出市值 | [labor-benefit.md](labor-benefit.md) |
| X19 | 转职计算器 Context 配置 vs 单表驱动 | [career-change-calculator.md](career-change-calculator.md) |
| X20 | 同一角色是否可同时拥有自由/雇佣职业或互斥 | [characters.md](characters.md) |

---

## 依赖关系（简图）

```
资源标签 ─→ 需求 / 预期库存；市价按品种
旅行商人 ─→ 场内货币总量 / 流通统计（同常驻角色）
期望价相关性 ─┬─→ 产出市值（完成时市价）─→ 转职分数
                    └─→ 商业净收入 / 住房实际等级 ─→ 建筑估值 ─→ 占格成交价 / 回购价

建筑估值 ─→ luxury-housing / 购置比价
领主审批流程 ─→ multi-tile-workshop
```

## 关联

- 索引入口：[SKILL.md](SKILL.md)
- 叙事检验：[beautiful-corners/README.md](beautiful-corners/README.md)
