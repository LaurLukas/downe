class_name BoardingSupportAbility
extends Ability

## The docked ship's Security Teams help repel boarders during a Wolf
## Attack's Boarding Action. Arithmetic helper only - it rolls the
## Boarding Defence table (open_questions_answered.md §3.3) for however
## many teams are committed, it doesn't decide whether to fight or run;
## the physical gathering at the battle table still happens (CLAUDE.md
## constraint 3).
##
## Boarding Defence table, 1d6 per engagement: 1 -> Security Team dies;
## 2-3 -> no effect; 4+ -> Wolf Assault Team dies.
##
## params: {team_count: int}

func can_execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	var ship := game_state.get_ship(craft_state.docked_ship_id)
	if ship == null:
		return AbilityCheck.denied("not docked at any ship")
	var team_count: int = params.get("team_count", 0)
	if team_count <= 0:
		return AbilityCheck.denied("team_count must be positive")
	if ship.resources.get_amount(ResourceStock.Kind.SECURITY_TEAMS) < team_count:
		return AbilityCheck.denied("not enough security teams on the docked ship")
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var craft_state := game_state.get_craft(craft_id)
	var ship := game_state.get_ship(craft_state.docked_ship_id)
	var team_count: int = params["team_count"]

	var rolls := _roll(game_state, team_count)
	return _apply(ship, rolls)

## Split out so BoardingSupportEliteAbility can reuse the roll+reroll
## machinery without duplicating the table.
func _roll(game_state: GameState, count: int) -> Array[int]:
	var rolls: Array[int] = []
	for i in count:
		rolls.append(game_state.rng.randi_range(1, 6))
	return rolls

func _apply(ship: Ship, rolls: Array[int]) -> AbilityResult:
	var teams_lost := 0
	var assault_teams_killed := 0
	for roll in rolls:
		if roll == 1:
			teams_lost += 1
		elif roll >= 4:
			assault_teams_killed += 1
	ship.resources.add(ResourceStock.Kind.SECURITY_TEAMS, -teams_lost)
	return AbilityResult.success({
		"rolls": rolls,
		"teams_lost": teams_lost,
		"assault_teams_killed": assault_teams_killed,
	})
