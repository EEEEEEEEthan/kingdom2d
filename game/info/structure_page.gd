extends Control

signal character_open_requested(character: Character)

const INVENTORY_PART := preload("res://game/info/parts/inventory_part.tscn")
const WORKPLACE_PART := preload("res://game/info/parts/workplace_part.tscn")
const RESIDENTS_PART := preload("res://game/info/parts/residents_part.tscn")
const UPGRADE_PART := preload("res://game/info/parts/upgrade_part.tscn")

var _structure: Structure


func bind(structure: Structure, characters: CharacterManager) -> void:
	_structure = structure
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.free()
	var title := Label.new()
	title.name = "Title"
	title.text = String(structure.config.name)
	%Rows.add_child(title)
	if structure.is_under_construction() or structure is SunkenFloorThatchHovel:
		var upgrade := UPGRADE_PART.instantiate()
		upgrade.name = "Upgrade"
		%Rows.add_child(upgrade)
		upgrade.bind(structure)
	if structure.is_built() and (structure is GathererHut or structure is LumberCamp or structure is Warehouse or structure is BuildersGuild):
		var workplace := WORKPLACE_PART.instantiate()
		workplace.name = "Workplace"
		%Rows.add_child(workplace)
		workplace.bind(structure, characters)
		workplace.character_open_requested.connect(func(character: Character) -> void: character_open_requested.emit(character))
	if structure.is_built() and _shows_inventory(structure):
		var inventory := INVENTORY_PART.instantiate()
		inventory.name = "Inventory"
		%Rows.add_child(inventory)
		inventory.bind(structure)
	if Food.is_dwelling(structure):
		var residents := RESIDENTS_PART.instantiate()
		residents.name = "Residents"
		%Rows.add_child(residents)
		residents.bind(structure, characters)
		residents.character_open_requested.connect(func(character: Character) -> void: character_open_requested.emit(character))


func alive() -> bool:
	return _structure != null and is_instance_valid(_structure)


func _process(_delta: float) -> void:
	if not alive():
		return
	var title := %Rows.get_node_or_null("Title") as Label
	if title and title.text != String(_structure.config.name):
		title.text = String(_structure.config.name)


func _shows_inventory(structure: Structure) -> bool:
	return structure is GathererHut or structure is LumberCamp or structure is Warehouse or Food.is_dwelling(structure)
