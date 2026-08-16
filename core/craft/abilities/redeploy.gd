class_name RedeployAbility
extends Ability

## requires_fuel. Move to any ship of the operator's choice, at the
## start of a Boarding Action. Pallas and Chepu.
##
## params: {target_ship_id: String}

func can_execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	if not craft_state.fuelled:
		return AbilityCheck.denied("not fuelled")
	var target_ship_id: String = params.get("target_ship_id", "")
	if game_state.get_ship(target_ship_id) == null:
		return AbilityCheck.denied("no such target ship")
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var craft_state := game_state.get_craft(craft_id)
	var target_ship_id: String = params["target_ship_id"]
	craft_state.set_docked_ship(target_ship_id)
	return AbilityResult.success({"docked_ship_id": target_ship_id})
