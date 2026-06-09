# 项目概览

## 定位

Kingdom2D：横向 2D 王国模拟。极窄横条视口（1024×64），地图 512 格 × 8px，可拖拽平移。

## 已实现雏形（代码现状）

- **时间**：现实 1h = 游戏 24h；7 天/月、12 月/年、四季、月相；日内分早市 / 工作 / 休息 / 睡眠（详见 [time.md](time.md)）
- **世界**：中心王权旌旗，随机橡树与灌木，地形、云层、日月
- **角色**：开局 8 人，当前仅 idle 漫游 AI；设计已定职业/转职/佣金/雇工薪酬，见 [characters.md](characters.md)
- **建筑**：可建造半穴茅舍（代码为即时放置）；设计已定占地、购地、地基填料与雇建筑工流程，见 [structures.md](structures.md)
- **持久化**：存档读写

## 相关子文档

- **开放决策**：[open-decisions.md](open-decisions.md)（未决问题优先级）
- 经济：[economy.md](economy.md)（货币总量恒定、需求按标签、市价按品种）
- 劳动获益：[labor-benefit.md](labor-benefit.md)（雇佣=佣金，生产类=完成时产出市值）
- 转职计算器：[career-change-calculator.md](career-change-calculator.md)（雇佣日薪底价 ==0）
- 建筑估值计算器：[building-valuation-calculator.md](building-valuation-calculator.md)（净收入 + 类型保底 + 竣工保护加成；占格交易成交价即估值）
- 角色：[characters.md](characters.md)（建筑工、转职、岗位雇佣、按日薪酬结算）
- 建筑：[structures.md](structures.md)（购地/购置、地基填料、雇工竣工、组合审批）
- 建筑运营：[commerce.md](commerce.md)；生活水平：[needs.md](needs.md)；日程：[time.md](time.md)
- 最美角落：[beautiful-corners/README.md](beautiful-corners/README.md)（叙事锚点，检验系统设计）
