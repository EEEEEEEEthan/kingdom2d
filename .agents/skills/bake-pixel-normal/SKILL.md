---
name: bake-pixel-normal
description: 从像素 diffuse 贴图烘焙 2D 法线贴图，颜色仅使用 GIMP 调色板（如 normal.gpl）中的条目。用于用户要求烘焙/重烘焙法线贴图、扩大法线过渡范围、或处理山体/剪影类 CanvasTexture 资产时。
---

# 烘焙像素法线贴图

## 何时使用

- 用户修改了 diffuse 图，需要同步法线贴图
- 需要从剪影/alpha 轮廓生成 Godot 2D 光照用的法线
- 用户要求法线颜色限制在 `normal.gpl` 调色板内
- 用户要求调整法线过渡宽度（更宽/更窄的坡面）

## 快速执行

```bash
python .agents/skills/bake-pixel-normal/scripts/bake_normal.py \
  game/terrain/mountains.png \
  -o game/terrain/mountains_normal.png \
  -p normal.gpl
```

依赖：`pillow`（`pip install pillow`）

## 算法

1. 用 diffuse 的 **alpha 通道** 作为高度场（不透明=高，透明=低）
2. 对高度场做 **高斯模糊**，控制过渡带宽度
3. 在模糊后的高度场上按 **采样跨度** 求梯度，得到法线向量
4. 将 RGB 量化到调色板最近色；透明像素用 `(128,128,255,0)`，实体内部平面用 `(128,128,255,255)`

## 参数调优

| 参数 | 默认 | 效果 |
|------|------|------|
| `--blur` | 10 | 越大，轮廓法线过渡带越宽 |
| `--span` | 6 | 梯度采样距离，配合 blur 控制坡度平滑度 |
| `--strength` | 4.0 | 坡度强度；过大易饱和到调色板极端色 |

用户说「过渡太窄」→ 增大 `--blur` 和/或 `--span`。  
用户说「过渡太宽/太软」→ 减小二者。

## Godot 接入要点

`CanvasTexture` 的 `diffuse_texture` / `normal_texture` **不要**嵌套 `AtlasTexture`，否则 2D 光照会丢 diffuse 发白。

正确做法（本项目惯例）：

```text
CanvasTexture → 整张贴图 + 整张贴图法线
Sprite2D.region_enabled = true
Sprite2D.region_rect = 对应行 Rect2
```

参考：`game/terrain/terrain.tscn` 中 `CanvasTexture_mountains` + `Sprite2D1`–`Sprite2D4`。

## 工作流

```
任务进度：
- [ ] 确认 diffuse 已保存
- [ ] 运行 bake_normal.py
- [ ] 若场景 region_rect 与图集行高不一致，同步 terrain.tscn
- [ ] Godot 重开或重新导入贴图验证光照
```

## 图集约定（本项目远山）

- 每行高度 48px，山体向下对齐
- 四行共用 `mountains.png` + `mountains_normal.png`
- 各行 `region_rect.y` 依次为 0、48、96、144
