class_name CargoTransferAbility
extends Ability

## Moves resources between a craft's cargo hold and the ship it's
## docked at. Coordination Phase only. Which kinds a craft may carry is
## fixed per craft (CraftDefinition.cargo_types) - e.g. the Hummingbird
## cannot move materials, the Pallas can only move security teams.
##
## params: {kind: ResourceStock.Kind, amount: int, direction: "to_ship" | "to_craft"}

func can_execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	var definition := CraftDefinitions.get_definition(craft_id)
	var kind: ResourceStock.Kind = params.get("kind", -1)
	if kind not in definition.cargo_types:
		return AbilityCheck.denied("%s cannot carry that cargo type" % definition.display_name)
	var amount: int = params.get("amount", 0)
	if amount <= 0:
		return AbilityCheck.denied("amount must be positive")
	var ship := game_state.get_ship(craft_state.docked_ship_id)
	if ship == null:
		return AbilityCheck.denied("not docked at any ship")

	var direction: String = params.get("direction", "to_ship")
	var source := craft_state.cargo if direction == "to_ship" else ship.resources
	if source.get_amount(kind) < amount:
		return AbilityCheck.denied("not enough of that resource to move")
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var craft_state := game_state.get_craft(craft_id)
	var ship := game_state.get_ship(craft_state.docked_ship_id)
	var kind: ResourceStock.Kind = params["kind"]
	var amount: int = params["amount"]
	var direction: String = params.get("direction", "to_ship")

	if direction == "to_ship":
		craft_state.cargo.add(kind, -amount)
		ship.resources.add(kind, amount)
	else:
		ship.resources.add(kind, -amount)
		craft_state.cargo.add(kind, amount)

	return AbilityResult.success({"kind": kind, "amount": amount, "direction": direction})
