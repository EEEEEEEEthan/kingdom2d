extends VBoxContainer

var _structure: Structure


func _ready() -> void:
	%UpgradeButton.pressed.connect(_on_pressed)
	if _structure:
		_sync()


func bind(structure: Structure) -> void:
	_structure = structure
	_sync()


func _process(_delta: float) -> void:
	if not is_inside_tree() or not get_window().visible:
		return
	if _structure == null or not is_instance_valid(_structure):
		return
	_sync()


func _sync() -> void:
	if not is_node_ready():
		return
	if _structure != null and _structure.is_under_construction():
		visible = true
		var button := %UpgradeButton as Button
		button.disabled = true
		button.text = "修建中"
		%Status.text = "原木 %d/%d · 建造 %d/%d" % [
			mini(_structure.container.count_of(ItemConfig.TypeId.LOG), _structure.builder_log_cost()),
			_structure.builder_log_cost(),
			_structure.builder_work_units(),
			_structure.builder_work_units_required(),
		]
		return
	var hovel := _structure as SunkenFloorThatchHovel
	if hovel == null or not hovel.is_built() or hovel.config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		visible = false
		return
	visible = true
	var button := %UpgradeButton as Button
	if hovel.upgrade_ordered:
		button.disabled = true
		button.text = "升级中"
		%Status.text = "原木 %d/%d · 建造 %d/%d" % [mini(hovel.log_count(), SunkenFloorThatchHovel.LOG_COST), SunkenFloorThatchHovel.LOG_COST, hovel.work_units, SunkenFloorThatchHovel.WORK_UNITS_REQUIRED]
	else:
		button.disabled = false
		button.text = "升级为木架茅屋"
		%Status.text = "需要 20 原木"


func _on_pressed() -> void:
	var hovel := _structure as SunkenFloorThatchHovel
	if hovel == null or not hovel.is_built() or hovel.upgrade_ordered or hovel.config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return
	hovel.order_upgrade()
	_sync()
