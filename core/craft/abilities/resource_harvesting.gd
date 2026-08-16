class_name ResourceHarvestingAbility
extends Ability

## Hummingbird only. requires_fuel. Roll 2d6; the operator picks one
## die as food, the other as water.
##
## params: {}

func can_execute(game_state: GameState, craft_id: String, _params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	if not craft_state.fuelled:
		return AbilityCheck.denied("not fuelled")
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

	var die_a := game_state.rng.randi_range(1, 6)
	var die_b := game_state.rng.randi_range(1, 6)
	var food_die_first: bool = params.get("food_die_first", true)
	var food_amount := die_a if food_die_first else die_b
	var water_amount := die_b if food_die_first else die_a

	ship.resources.add(ResourceStock.Kind.FOOD, food_amount)
	ship.resources.add(ResourceStock.Kind.WATER, water_amount)

	return AbilityResult.success({"food": food_amount, "water": water_amount})
