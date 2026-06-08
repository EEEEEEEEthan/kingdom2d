# 开放决策（优先级）

> 尚未敲定的设计问题汇总。子文档正文只记**已定**规则；本节按**阻塞关系**排序，供讨论时优先裁决。
>
> 格式：`[P0/P1/P2]` 优先级 · 来源文档 · 问题 · 阻塞什么

---

## P1 — 经济扩展（旅行商人）

| # | 问题 | 来源 | 阻塞 |
|---|------|------|------|
| E8 | **旅行商人入境/离境如何改变场内货币总量**；是否计入流通货币与期望价统计 | [economy.md](economy.md) | 货币总量恒定、价格形成 |

---

## P2 — 边界与 polish

| # | 问题 | 来源 |
|---|------|------|
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
资源标签 ─→ 需求 / 预期库存；市价按品种
旅行商人 (E8) ─→ 场内货币总量 / 期望价边界
期望价相关性 ─┬─→ 产出市值（完成时市价）─→ 转职分数
                    └─→ 商业净收入 / 住房实际等级 ─→ 建筑估值 ─→ 占格成交价 / 回购价

建筑估值 ─→ luxury-housing / 购置比价
领主审批流程 ─→ multi-tile-workshop
```

## 关联

- 索引入口：[SKILL.md](SKILL.md)
- 叙事检验：[beautiful-corners/README.md](beautiful-corners/README.md)
