# 开放决策（优先级）

> 尚未敲定的设计问题汇总。子文档正文只记**已定**规则；本节按**阻塞关系**排序，供讨论时优先裁决。
>
> 格式：`[P0/P1/P2]` 优先级 · 来源文档 · 问题 · 阻塞什么

---

## P1 — 转职 / 雇佣闭环（阻塞角色 AI 日循环）

| # | 问题 | 来源 | 阻塞 |
|---|------|------|------|
| C7 | **雇佣离职转职：候选权重均 ≤ 0 时如何处理** | [labor-benefit.md](labor-benefit.md) · [characters.md](characters.md) | 边缘 case |

---

## P1 — 建造流程（阻塞 structures 实现）

| # | 问题 | 来源 | 阻塞 |
|---|------|------|------|
| B1 | **购地价为全局一口价还是按格/按类型可区分** | [structures.md](structures.md) | 购地审批、组合方案比价 |
| B2 | **组合方案执行顺序**；任一步失败是否回滚 | [structures.md](structures.md) | [multi-tile-workshop](beautiful-corners/multi-tile-workshop.md) |
| B3 | **审批排队期间是否锁定涉及格子** | [structures.md](structures.md) | 抢建、整单重验 |
| B4 | **材料种类、数量、填料耗时** | [structures.md](structures.md) | 地基→填料→雇工链 |
| B5 | **多格 Footprint 形状模板** | [structures.md](structures.md) | 多格占地实现 |

---

## P2 — 边界与 polish

| # | 问题 | 来源 |
|---|------|------|
| X1 | 非角色第三方是否参与货币流通 | [economy.md](economy.md) |
| X2 | 角色死亡/离场时货币处理 | [economy.md](economy.md) |
| X3 | 刚刚转职标记持续时长 | [characters.md](characters.md) |
| X4 | 雇佣选人：最低价者不可雇时是否取次低 | [career-change-calculator.md](career-change-calculator.md) |
| X5 | 拆毁是否消耗物料/劳动 | [structures.md](structures.md) |
| X6 | 购置候选格枚举范围 | [structures.md](structures.md) |
| X7 | 建造责任方死亡/欠薪时工地处理 | [structures.md](structures.md) |
| X8 | 空地是否排除环境物占格 | [structures.md](structures.md) |
| X9 | 各建筑类型邻域/地形规则表 | [structures.md](structures.md) |
| X10 | 待办队列 UI 节点、校验失败反馈文案 | [structures.md](structures.md) |
| X11 | 劳动获益 UI / 平衡用途 | [labor-benefit.md](labor-benefit.md) |
| X12 | 实现层命名与统计缓存 | 各计算器文档 |

---

## 依赖关系（简图）

```
期望价相关性 ─┬─→ 产出市值（完成时市价）─→ 转职分数
                    └─→ 商业净收入 / 住房实际等级 ─→ 建筑估值 ─→ 占格成交价 / 回购价

建筑估值 ─→ luxury-housing / 购置比价
B2/B3 组合审批 ─→ multi-tile-workshop
```

## 关联

- 索引入口：[SKILL.md](SKILL.md)
- 叙事检验：[beautiful-corners/README.md](beautiful-corners/README.md)
