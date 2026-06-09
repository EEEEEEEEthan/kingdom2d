# Kingdom2D 系统设计待决清单

> 自 [系统设计 skill](.agents/skills/system-design/) 审查整理，供逐条讨论后写入对应子文档。  
> **状态**：`待决` | `已决`（已决项移入 skill 后可删或标删）  
> **用法**：从上往下或按优先级挑一条，讨论确认后更新 skill，再把本条标为已决。

---

## 已决（近期）

| # | 议题 | 结论去向 |
|---|------|----------|
| R01 | 占格重叠时是否须领主审批、购地价计哪些格 | [structures.md](.agents/skills/system-design/structures.md)「占格覆盖与购地审批」 |
| R02 | AI 是否可拆玩家建筑 | 同上「AI 选址约束」 |
| R03 | 商业建筑为经济单位、运营储备、商业雇员 | [commerce.md](.agents/skills/system-design/commerce.md) |
| R04 | 铺面代摊、分建筑上岗窗口、标准上岗时长 | [commerce.md](.agents/skills/system-design/commerce.md)、[time.md](.agents/skills/system-design/time.md)、[economy.md](.agents/skills/system-design/economy.md)「早市」 |

---

## P0 — 闭环缺口（无则难以跑通模拟）

### D01 商业建筑经营模型

- **状态**：已决（[commerce.md](.agents/skills/system-design/commerce.md)、[time.md](.agents/skills/system-design/time.md)）；店内选购 AI 细节随 D04/D05 实现期定

---

### D02 角色为何建房 / 换房（住房需求侧）

- **状态**：待决
- **写入目标**：[characters.md](.agents/skills/system-design/characters.md) 和/或新建 `needs.md`
- **问题**：经济文档有【食物】标签需求，但**住房需求**、升级动机（简陋→奢侈）、不住满是否仍要自有住房，均未定义。
- **阻塞**：建造 AI 决策（只有成本侧、无需求侧）、奢侈住房叙事里的「攒够钱想搬家」。
- **讨论要点**：
  - 住房是硬需求（容量/睡眠）还是软偏好（体面、实际住房等级收益）？
  - 租房/合租是否存在，还是只有自建？

---

### D03 建筑主人与土地产权

- **状态**：待决
- **写入目标**：[structures.md](.agents/skills/system-design/structures.md)
- **问题**：
  1. **建筑主人**何时确立（竣工瞬间？购地后？）；
  2. **购置占格**后，卖方曾向领主购得的**土地所有权**是否随交易转移给买方；
  3. 多格 Footprint **按格权属**混有购地格 + 购置格时，如何记录；
  4. 领主回购买的是建筑还是「建筑 + 土地」。
- **阻塞**：购置结算、回购、组合方案产权链、AI 选址约束里的「建筑主人」判定。
- **讨论要点**：
  - 是否一律「谁竣工谁为建筑主人，土地随占格走」？
  - **被覆盖**格无购地时，土地权从哪来？

---

### D04 自由职业与生产行为清单

- **状态**：待决
- **写入目标**：[characters.md](.agents/skills/system-design/characters.md) + 可选 `careers.md`
- **问题**：仅「采浆果」示例；谁建铁匠铺/酒馆、生产行为如何触发、与日内时段（工作/早市）关系未写。
- **阻塞**：转职计算器输入、劳动获益样本、场内供给循环。
- **讨论要点**：
  - 首版最少几种自由职业？
  - 生产类职业是否必须绑定某类商业建筑？

---

### D05 角色间交易与早市

- **状态**：部分已决（早市双渠道、日价成交 → [economy.md](.agents/skills/system-design/economy.md)「早市」）
- **未决**：摆摊概率、买家选购、是否支持挂单
- **阻塞**：流通商品细粒度 AI

---

## P1 — 规则歧义（已定机制内的洞或冲突）

### D06 雇佣离职后转职权重全 ≤ 0

- **状态**：待决
- **写入目标**：[characters.md](.agents/skills/system-design/characters.md) + [labor-benefit.md](.agents/skills/system-design/labor-benefit.md)
- **问题**：离职抽取无空白，但若所有自由职业权重 ≤ 0 则**不转职**——此时雇佣已结束，角色职业状态**未定义**。
- **阻塞**：解雇/竣工/欠薪后的角色状态机。
- **候选**：
  - A. 保底落回离职前自由职业
  - B. 强制随机抽一个自由职业（忽略 ≤0）
  - C. 保留原自由职业「记忆」直至下次成功转职

---

### D07 欠薪后工地状态

- **状态**：待决
- **写入目标**：[structures.md](.agents/skills/system-design/structures.md)
- **问题**：欠薪立即解雇建筑工，但工地进度**保留还是停工**、能否换工续建、材料是否锁定，写「待后续设计」。
- **阻塞**：建造施工流程的异常分支实现。

---

### D08 服务等级与商业冷启动

- **状态**：待决
- **写入目标**：[structures.md](.agents/skills/system-design/structures.md)
- **问题**：高等级住房依赖邻域商业；商业又要有净收入。第一家店谁建、为何建，未设计。
- **阻塞**：开局布局、住房升级路径是否可达。
- **讨论要点**：是否允许「低服务等级先入住」、或开局强制种子商业？

---

### D09 同一角色自由职业与雇佣职业是否互斥

- **状态**：待决（原 open-decisions **X20**）
- **写入目标**：[characters.md](.agents/skills/system-design/characters.md)
- **问题**：受雇期间是否仍算某自由职业、能否日常转职、挖墙脚后旧岗位如何处理——文档隐含互斥但未写明。
- **阻塞**：转职日更、劳动获益分段、UI 展示「当前职业」。

---

## P2 — 实现期 / polish（原 open-decisions + 审查项）

| # | 议题 | 写入目标 | 备注 |
|---|------|----------|------|
| D10 | 受雇建筑工能否同时参与多处施工（X13） | structures.md | 与「责任方仅一处工地」不同维度 |
| D11 | 领主回购后建筑/土地处置与购回 UI（X14） | structures.md | 依赖 D03 |
| D12 | 雇员薪酬结算时刻：午夜还是早市等（X15） | characters.md + time.md? | 与 D05 联动 |
| D13 | 商业净收入收支事件统计口径（X16） | building-valuation-calculator.md | 依赖 D01 |
| D14 | 估值金额映射、未竣工工地计价、刷新周期、购地价是否纳入估值（X17） | building-valuation-calculator.md | |
| D15 | 非整日劳动、多商品职业、建筑被动产出是否计入产出市值（X18） | labor-benefit.md | |
| D16 | 转职计算器 Context 配置 vs 单表驱动（X19） | career-change-calculator.md | 实现向 |
| D17 | 实现层命名与统计缓存（X12） | 各计算器文档 | 实现向 |
| D18 | 角色死亡时货币/资源/工地（economy + structures 均写「暂不处理」） | economy.md + characters.md + structures.md | 是否纳入首版 |
| D19 | 拆毁零成本是否导致「只买格不经营」主导策略 | structures.md / economy.md | 平衡观察，可后验调 |

---

## P3 — 经济与平衡风险（观察项，裁决时可一并记入 skill）

| # | 风险 | 相关文档 |
|---|------|----------|
| W01 | 领主 80% 货币不计流通 → 刻意压低流通量；领主只进不出时通胀偏弱 | economy.md |
| W02 | 产出市值用完成时市价 ↔ 定价参数互相喂养，转职可能过敏 | labor-benefit.md, economy.md |
| W03 | 转职权重和 > 100 时空白为 0，是否归一化未定 → 转职频率波动 | labor-benefit.md |
| W04 | 角色详情与转职计算器「平均劳动获益」可用不同统计窗口 | labor-benefit.md |

---

## 建议讨论顺序

```
D03 产权链 → D01 商业经营 → D13/D14 估值口径
     ↓
D05 交易 → D04 职业清单 → D02 住房需求
     ↓
D09 职业互斥 → D06 离职转职 → D07 欠薪工地
     ↓
D08 冷启动 → P2 表内各项
```

---

## 维护

- 本条目标录**不是** skill 真源；确认后的规则只写入 `.agents/skills/system-design/` 子文档。
- 已决项在 skill 落地后，将上表对应行标为 `已决` 并链到 commit 或章节名。
- 与 [open-decisions.md](.agents/skills/system-design/open-decisions.md) 关系：skill 内 open-decisions 在逐条关闭后应同步删减或降级。
