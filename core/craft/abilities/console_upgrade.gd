class_name ConsoleUpgradeAbility
extends Ability

## Endeavour only. Upgrades up to 2 consoles per turn on the target
## ship, 4 if fuelled.
##
## NOT IMPLEMENTED: the materials cost. downe_shuttle_implementation_prompt.md
## says "paying the leftmost unlocked cost in materials", and ships.md
## confirms the upgrade track has 5 boxes on most consoles (4 on the
## Dione's VIP Lounge) - but no source document gives the actual
## material cost per box. Rather than invent numbers, this only
## increments Console.upgrade_level and charges nothing. Do not treat
## this as usable at the table until the cost track is sourced - see
## TODO.md.
##
## params: {ship_id: String, console_ids: Array[String]}

const BASE_MAX_UPGRADES := 2
const FUELLED_MAX_UPGRADES := 4

func can_execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	var ship := game_state.get_ship(params.get("ship_id", ""))
	if ship == null:
		return AbilityCheck.denied("no such ship")
	var console_ids: Array = params.get("console_ids", [])
	if console_ids.is_empty():
		return AbilityCheck.denied("no consoles requested")
	var max_upgrades := FUELLED_MAX_UPGRADES if craft_state.fuelled else BASE_MAX_UPGRADES
	if console_ids.size() > max_upgrades:
		return AbilityCheck.denied("can upgrade at most %d consoles this turn" % max_upgrades)
	for console_id: String in console_ids:
		if ship.get_console(console_id) == null:
			return AbilityCheck.denied("no such console: %s" % console_id)
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var ship := game_state.get_ship(params["ship_id"])
	var console_ids: Array = params["console_ids"]
	for console_id: String in console_ids:
		ship.get_console(console_id).upgrade()
	return AbilityResult.success({"consoles_upgraded": console_ids.size(), "materials_charged": 0})
