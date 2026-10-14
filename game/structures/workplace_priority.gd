extends RefCounted
class_name WorkplacePriority

## 工作建筑与仓库共用的优先级档位。

enum Priority {
	LOW,
	NORMAL,
	HIGH,
}

const WEIGHTS := [2, 3, 6]
const NAMES := ["低优先", "普通", "高优先"]
