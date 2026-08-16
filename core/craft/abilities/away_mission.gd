class_name AwayMissionAbility
extends Ability

## The craft may join an away mission, contributing its skill bonus as
## the shuttle_bonus term to AwayMissionOpportunity.score(). This only
## reports the bonus - which cards go to which opportunity, and who
## leads the mission, stay a human negotiation. See CLAUDE.md
## constraint 2.
##
## params: {skill: AwayMissionOpportunity.Skill}

func can_execute(game_state: GameState, craft_id: String, _params: Dictionary) -> AbilityCheck:
	if game_state.get_craft(craft_id) == null:
		return AbilityCheck.denied("no such craft")
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var definition := CraftDefinitions.get_definition(craft_id)
	var skill: AwayMissionOpportunity.Skill = params.get("skill", -1)
	var bonus: int = definition.away_mission_bonuses.get(skill, 0)
	return AbilityResult.success({"skill": skill, "bonus": bonus})
