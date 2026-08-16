class_name StorageDamage
extends RefCounted

## When a ship's Storage console is damaged, half its resources are
## discarded - including resources sitting on any docked shuttles.
## downe_shuttle_implementation_prompt.md §2. Not yet wired to anything
## automatic (no Maintenance Cycle exists - see TODO.md); call this
## directly wherever a Storage console gets damaged.
##
## Rounding: losses round down. For 5 food, floor(5/2)=2 is discarded,
## leaving 3 - "5 food becomes 3 food" per the brief, which is what
## motivates a dedicated test at exactly that value.

const STORAGE_CONSOLE_ID := "storage"

static func apply_if_damaged(game_state: GameState, ship_id: String) -> void:
	var ship := game_state.get_ship(ship_id)
	if ship == null:
		return
	var storage := ship.get_console(STORAGE_CONSOLE_ID)
	if storage == null or storage.state != Console.State.DAMAGED:
		return

	_halve(ship.resources)
	for craft_id: String in game_state.craft:
		var craft_state := game_state.craft[craft_id]
		if craft_state.docked_ship_id == ship_id:
			_halve(craft_state.cargo)

static func _halve(stock: ResourceStock) -> void:
	for kind in [
		ResourceStock.Kind.STRYTIUM_ORE, ResourceStock.Kind.STRYTIUM_FUEL,
		ResourceStock.Kind.FOOD, ResourceStock.Kind.WATER,
		ResourceStock.Kind.MATERIALS, ResourceStock.Kind.SECURITY_TEAMS,
	]:
		var amount := stock.get_amount(kind)
		if amount <= 0:
			continue
		var lost := amount / 2
		stock.set_amount(kind, amount - lost)
