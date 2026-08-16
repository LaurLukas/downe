class_name ScoutSystemAbility
extends Ability

## Records whatever coordinates the scout reports, verbatim. Never
## validated against real star system data, never auto-filled, never
## flagged as wrong - a Wolf agent operating a scout craft must be able
## to lie. See CLAUDE.md constraint 1.
##
## Range limits ("within 2 jumps", "any system") govern what a scout
## can *truthfully* find in-fiction, not what this method will accept -
## enforcing them here would mean catching liars, which is exactly what
## this system must never do. Only the per-turn use count is enforced.
##
## params: {report: String}

const ABILITY_ID := "scout_system"

## craft_id -> [base uses per turn, uses added if fuelled]
const USE_LIMITS := {
	"starlight": [1, 1],
	"hummingbird": [1, 0],
	"endeavour": [1, 0],
}

func can_execute(game_state: GameState, craft_id: String, _params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	var limits: Array = USE_LIMITS.get(craft_id, [1, 0])
	var max_uses: int = limits[0] + (limits[1] if craft_state.fuelled else 0)
	if craft_state.get_uses(ABILITY_ID) >= max_uses:
		return AbilityCheck.denied("no scouting uses remaining this turn")
	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var craft_state := game_state.get_craft(craft_id)
	craft_state.set_scout_report(params.get("report", ""))
	craft_state.record_use(ABILITY_ID)
	return AbilityResult.success({"report": craft_state.scout_report})
