class_name BoardingSupportEliteAbility
extends BoardingSupportAbility

## As BoardingSupportAbility, plus re-rolling up to 3 dice that came up
## "Security Team dies" - Pallas only.
##
## params: {team_count: int}

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var craft_state := game_state.get_craft(craft_id)
	var ship := game_state.get_ship(craft_state.docked_ship_id)
	var team_count: int = params["team_count"]

	var rolls := _roll(game_state, team_count)
	var rerolled := 0
	for i in rolls.size():
		if rerolled >= 3:
			break
		if rolls[i] == 1:
			rolls[i] = game_state.rng.randi_range(1, 6)
			rerolled += 1

	return _apply(ship, rolls)
