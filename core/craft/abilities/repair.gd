class_name RepairAbility
extends Ability

## Two mutually exclusive modes:
##
## "repair": fix up to 2 consoles on 1 ship, 4 materials each, drawn
## from that ship's hold. requires_fuel extends this to a second ship
## (still up to 2 consoles per ship).
## params: {mode: "repair", repairs: Array[{ship_id: String, console_id: String}]}
##
## "damage_for_materials": damage one intact console to gain 3
## materials for its ship. This requires the consent of at least one
## player on that ship - a two-party confirmation the caller must
## already have obtained, never a unilateral host/craft action.
## params: {mode: "damage_for_materials", ship_id: String, console_id: String, consent: bool}

const REPAIR_COST_PER_CONSOLE := 4
const MAX_CONSOLES_PER_SHIP := 2
const DAMAGE_FOR_MATERIALS_GAIN := 3

func can_execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")

	var mode: String = params.get("mode", "repair")
	if mode == "damage_for_materials":
		return _check_damage_for_materials(game_state, params)
	return _check_repair(game_state, craft_state, params)

func _check_damage_for_materials(game_state: GameState, params: Dictionary) -> AbilityCheck:
	if not params.get("consent", false):
		return AbilityCheck.denied("requires consent from a player on that ship")
	var ship := game_state.get_ship(params.get("ship_id", ""))
	if ship == null:
		return AbilityCheck.denied("no such ship")
	var console := ship.get_console(params.get("console_id", ""))
	if console == null:
		return AbilityCheck.denied("no such console")
	if console.state != Console.State.OK:
		return AbilityCheck.denied("console is not intact")
	return AbilityCheck.allowed()

func _check_repair(game_state: GameState, craft_state: CraftState, params: Dictionary) -> AbilityCheck:
	var repairs: Array = params.get("repairs", [])
	if repairs.is_empty():
		return AbilityCheck.denied("no repairs requested")

	var consoles_per_ship: Dictionary[String, int] = {}
	var materials_needed: Dictionary[String, int] = {}
	for entry: Dictionary in repairs:
		var ship_id: String = entry.get("ship_id", "")
		var ship := game_state.get_ship(ship_id)
		if ship == null:
			return AbilityCheck.denied("no such ship")
		var console := ship.get_console(entry.get("console_id", ""))
		if console == null:
			return AbilityCheck.denied("no such console")
		consoles_per_ship[ship_id] = consoles_per_ship.get(ship_id, 0) + 1
		materials_needed[ship_id] = materials_needed.get(ship_id, 0) + REPAIR_COST_PER_CONSOLE

	if consoles_per_ship.size() > 2:
		return AbilityCheck.denied("can repair on at most 2 ships")
	if consoles_per_ship.size() > 1 and not craft_state.fuelled:
		return AbilityCheck.denied("not fuelled - can only repair on 1 ship")
	for ship_id: String in consoles_per_ship:
		if consoles_per_ship[ship_id] > MAX_CONSOLES_PER_SHIP:
			return AbilityCheck.denied("can repair at most %d consoles per ship" % MAX_CONSOLES_PER_SHIP)
		var ship := game_state.get_ship(ship_id)
		if ship.resources.get_amount(ResourceStock.Kind.MATERIALS) < materials_needed[ship_id]:
			return AbilityCheck.denied("not enough materials on %s" % ship_id)

	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var mode: String = params.get("mode", "repair")
	if mode == "damage_for_materials":
		var ship := game_state.get_ship(params["ship_id"])
		var console := ship.get_console(params["console_id"])
		console.damage()
		ship.resources.add(ResourceStock.Kind.MATERIALS, DAMAGE_FOR_MATERIALS_GAIN)
		return AbilityResult.success({"materials_gained": DAMAGE_FOR_MATERIALS_GAIN})

	var repairs: Array = params["repairs"]
	for entry: Dictionary in repairs:
		var ship := game_state.get_ship(entry["ship_id"])
		var console := ship.get_console(entry["console_id"])
		console.repair()
		ship.resources.add(ResourceStock.Kind.MATERIALS, -REPAIR_COST_PER_CONSOLE)
	return AbilityResult.success({"consoles_repaired": repairs.size()})
