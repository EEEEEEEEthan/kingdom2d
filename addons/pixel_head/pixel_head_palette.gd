@tool
extends Resource
class_name PixelHeadPalette

## 一个部位一份色板。下标对应这里的颜色，直接改这份资源即可。

@export var colors: PackedColorArray


func color_count() -> int:
	return colors.size()


func color_at(idx: int) -> Color:
	return colors[posmod(idx, colors.size())]
