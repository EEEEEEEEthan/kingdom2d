extends Control

signal character_open_requested(character: Character)

const INVENTORY_PART := preload("res://game/info/parts/inventory_part.tscn")
const WORKPLACE_PART := preload("res://game/info/parts/workplace_part.tscn")
const RESIDENTS_PART := preload("res://game/info/parts/residents_part.tscn")

var _structure: Structure


func bind(structure: Structure, characters: CharacterManager) -> void:
	_structure = structure
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.free()
	var title := Label.new()
	title.text = String(structure.config.name)
	%Rows.add_child(title)
	if structure is GathererHut or structure is Warehouse:
		var workplace := WORKPLACE_PART.instantiate()
		workplace.name = "Workplace"
		%Rows.add_child(workplace)
		workplace.bind(structure, characters)
		workplace.character_open_requested.connect(func(character: Character) -> void: character_open_requested.emit(character))
	if _shows_inventory(structure):
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


func _shows_inventory(structure: Structure) -> bool:
	return structure is GathererHut or structure is Warehouse or Food.is_dwelling(structure)
