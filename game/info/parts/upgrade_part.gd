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
		var site_button := %UpgradeButton as Button
		site_button.disabled = true
		site_button.text = "修建中"
		%Status.text = "原木 %d/%d · 建造 %d/%d" % [
			mini(_structure.container.count_of(ItemConfig.TypeId.LOG), _structure.builder_log_cost()),
			_structure.builder_log_cost(),
			_structure.builder_work_units(),
			_structure.builder_work_units_required(),
		]
		return
	var home := _structure as Dwelling
	if home == null or not home.is_built() or not Food.is_dwelling(home):
		visible = false
		return
	visible = true
	var button := %UpgradeButton as Button
	if home.upgrade_ordered:
		button.disabled = true
		button.text = "升级中"
		%Status.text = "原木 %d/%d · 建造 %d/%d" % [mini(home.log_count(), Dwelling.COTTAGE_LOG_COST), Dwelling.COTTAGE_LOG_COST, home.work_units, Dwelling.COTTAGE_WORK_UNITS]
		return
	if home.level >= DwellingGrade.LEVEL_TIMBER:
		button.disabled = true
		button.text = "原木宅"
		%Status.text = _stock_line(home)
		return
	if home.level >= DwellingGrade.LEVEL_COTTAGE:
		button.disabled = not DwellingGrade.can_raise(home, DwellingGrade.LEVEL_TIMBER)
		button.text = "升级为原木宅"
		%Status.text = "仓库原木 %d/%d" % [DwellingGrade.withdrawable_logs(home), DwellingGrade.LOG_NEED]
		return
	button.disabled = not DwellingGrade.can_raise(home, DwellingGrade.LEVEL_COTTAGE)
	button.text = "升级为木架茅屋"
	%Status.text = "居民 %d · 浆果 %d/%d" % [DwellingGrade.resident_count(home), Food.stored(home), Food.PER_DAY]


func _stock_line(home: Dwelling) -> String:
	return "居民 %d · 浆果 %d/%d · 仓库原木 %d/%d" % [
		DwellingGrade.resident_count(home),
		Food.stored(home),
		Food.PER_DAY,
		DwellingGrade.withdrawable_logs(home),
		DwellingGrade.LOG_NEED,
	]


func _on_pressed() -> void:
	var home := _structure as Dwelling
	if home == null:
		return
	if home.level < DwellingGrade.LEVEL_COTTAGE and DwellingGrade.can_raise(home, DwellingGrade.LEVEL_COTTAGE):
		home.order_upgrade()
	elif DwellingGrade.can_raise(home, DwellingGrade.LEVEL_TIMBER):
		home.promote_timber()
	_sync()
