extends Control

var inventory: Inventory:
	set(value):
		inventory = value
		if not is_node_ready():
			await ready
		%InventoryLabel.refresh_item_counts(inventory)
