# 尽量少 export，只用一次的值直接写死

## 踩坑

给变量加 `@export` 或 `const`，但实际只在一个地方用到，且不需要外部配置。

## 正确做法

- 尽可能少用 `@export`。如果需要我会提需求。
- 只用一次的值直接写死（字面量），不要 `const`，也不要变量。

## 反面案例

`character.gd` 的 `move_speed_pixels_per_second` 声明为 `@export var`，实际只在 `advance_toward_world_x` 里用了一次，不需要外部配置也不需要复用，直接写 `6.0` 即可。
