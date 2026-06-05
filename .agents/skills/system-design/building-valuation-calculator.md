# 建筑估值计算器

> 对**建筑实例**给出客观**估值**（货币金额）。与 [career-change-calculator.md](career-change-calculator.md)（雇佣日薪议价）分离；占格购置/回购成交价机制见 [structures.md](structures.md)。

### 核心机制

- **规则**：输入建筑实例（类型、占格、耐久/HP、建造记录等），输出该实例在当前经济环境下的**估值**（单一金额，非区间）。
- **说明**：
  - **不是**成交价、日薪或地契价；不表达卖方主观保留
  - **不是** [economy.md](economy.md) 中同质「流通商品」的日市价公式；商品市价可作为本计算器的**输入**（物料折钱）
  - 估值是否、如何参与占格购置/回购成交价，见 [structures.md](structures.md) 购置询价开放问题

### 估值输入（概念层）

- **规则**：估值须能吸收下列类数据（具体公式未定的标为开放问题）：
  - **物料**：按建造或重置所需物料，以**当日商品市价**折钱（见 [economy.md](economy.md)）
  - **劳动**：该建筑类型对应的社会必要劳动时间（建造行为须记时，见 [economy.md](economy.md)「社会必要劳动时间」）
  - **实例状态**：如 HP / 完工度（含仅地基、填料未满的工地如何计价）
  - **类型与占格**：`StructureConfig`、单格或多格 Footprint
- **说明**：
  - 多格建筑、未竣工工地是否按完成态比例估值，尚未确定

## 用途（按场景）

| 场景 | 文档 | 说明 |
|------|------|------|
| 物料/劳动记账与平衡 | [economy.md](economy.md) | 劳动时间统计、商品市价供给估值折钱 |

## 开放问题

见 [open-decisions.md](open-decisions.md) **S3**（v0 公式）、**S1/S2**（成交价关系）；其余：工地阶段是否按完成度比例、估值是否每日刷新、购地价是否纳入本计算器（随 S3/S1 一并定）。

## 关联

- 转职计算器：[career-change-calculator.md](career-change-calculator.md)
- 建筑 / 占格：[structures.md](structures.md)
- 经济：[economy.md](economy.md)
