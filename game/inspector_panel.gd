extends Control
class_name InspectorPanel

func inspect_character(character: Character) -> void:
	if not is_node_ready():
		await ready
	if not has_node("%InventoryPanel"):
		var inventory_panel := %InventoryPanelPlaceHolder.create_instance() as Control
		inventory_panel.name = "InventoryPanel"
		inventory_panel.owner = self
		inventory_panel.unique_name_in_owner = true
	if not has_node("%AiStatusPanel"):
		var ai_status_panel := %AiStatusPanelPlaceHolder.create_instance() as Control
		ai_status_panel.name = "AiStatusPanel"
		ai_status_panel.owner = self
		ai_status_panel.unique_name_in_owner = true
	%InventoryPanel.inventory = character.inventory
	%AiStatusPanel.character = character
