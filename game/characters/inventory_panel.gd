extends Control

@onready var _inventory_label: Label = %InventoryLabel

var inventory: Inventory:
	set(value):
		inventory = value
		if not is_node_ready():
			await ready
		_inventory_label.refresh_item_counts(inventory)


func _process(_delta: float) -> void:
	if not inventory:
		return
	_inventory_label.refresh_item_counts(inventory)
