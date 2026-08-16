class_name RechargeAbility
extends Ability

## requires_fuel. Charges one console directly, outside the normal
## Reactor step. Consoles whose effect normally triggers in the
## Maintenance Cycle would trigger immediately instead - that
## triggering isn't modeled here (no console has its effect
## implemented yet, see TODO.md); this only sets the charge flag.
##
## params: {ship_id: String, console_id: String}

func can_execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	if not craft_state.fuelled:
		return AbilityCheck.denied("not fuelled")
	var ship := game_state.get_ship(params.get("ship_id", ""))
	if ship == null:
		return AbilityCheck.denied("no such ship")
	var console := ship.get_console(params.get("console_id", ""))
	if console == null:
		return AbilityCheck.denied("no such console")
	if console.state != Console.State.OK:
		return AbilityCheck.denied("a damaged console cannot be charged")
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var ship := game_state.get_ship(params["ship_id"])
	var console := ship.get_console(params["console_id"])
	console.set_charged(true)
	return AbilityResult.success({"console_id": console.id})
