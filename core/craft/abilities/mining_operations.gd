class_name MiningOperationsAbility
extends Ability

## Highwall only. Up to 2 operations per turn (3 if fuelled). Each
## operation, the operator picks one: roll 1d6 for materials, or roll
## 3d6 for strytium ore - resolved as an open question with the user:
## the operator chooses independently each time, it isn't both per
## operation.
##
## params: {choice: "materials" | "ore"}

const ABILITY_ID := "mining_operations"
const BASE_OPERATIONS_PER_TURN := 2
const FUELLED_OPERATIONS_PER_TURN := 3

func can_execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	var choice: String = params.get("choice", "")
	if choice != "materials" and choice != "ore":
		return AbilityCheck.denied("choice must be 'materials' or 'ore'")
	var max_operations := FUELLED_OPERATIONS_PER_TURN if craft_state.fuelled else BASE_OPERATIONS_PER_TURN
	if craft_state.get_uses(ABILITY_ID) >= max_operations:
		return AbilityCheck.denied("no mining operations remaining this turn")
	var ship := game_state.get_ship(craft_state.docked_ship_id)
	if ship == null:
		return AbilityCheck.denied("not docked at any ship")
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var craft_state := game_state.get_craft(craft_id)
	var ship := game_state.get_ship(craft_state.docked_ship_id)
	var choice: String = params["choice"]

	var gained := 0
	if choice == "materials":
		gained = game_state.rng.randi_range(1, 6)
		ship.resources.add(ResourceStock.Kind.MATERIALS, gained)
	else:
		for i in 3:
			gained += game_state.rng.randi_range(1, 6)
		ship.resources.add(ResourceStock.Kind.STRYTIUM_ORE, gained)

	craft_state.record_use(ABILITY_ID)
	return AbilityResult.success({"choice": choice, "gained": gained})
