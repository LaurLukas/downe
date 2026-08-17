class_name StarSystemDefinition
extends RefCounted

## Static description of one star system - data, not behavior. Built
## via from_dict() so the roster in star_system_definitions.gd can stay
## close to open_questions_answered.md §1.2's table shape. Mirrors
## CraftDefinition's split from CraftState: this is the fixed content
## every game shares; StarSystem is the per-game mutable instance.

var letter: String = ""
var display_name: String = ""
## "Poor", "Neutral", or "" for systems the source table leaves
## unrated (printed as "—").
var rating: String = ""

## "X cards / Y opportunities" as printed - descriptive only. Y matches
## opportunities.size() by construction; cards_dealt is the one piece
## of information not otherwise derivable.
var cards_dealt: int = 0

var opportunities: Array[AwayMissionOpportunity] = []

## J and K repeat every turn instead of "once per new destination"
## (open_questions_answered.md §1.3).
var repeatable_each_turn: bool = false

## --- standing effects: these belong on the system, not on any one
## opportunity (source doc §1.2's own framing). All default to "no
## effect" so most systems don't need to mention them.

## G only: jumping here does not reduce the Pursuit Track.
var suppresses_pursuit_reduction: bool = false

## I only: the Pursuit Track is not raised while the fleet is here.
var suppresses_pursuit_rise_while_present: bool = false

## I: 3, J: 4, else -1 (no maintenance-phase damage roll). "Each ship
## takes damage on an N+" during the Maintenance Cycle - not enforced
## anywhere yet, since the Maintenance Cycle itself doesn't exist in
## core/ yet (see TODO.md's Turn phase structure item). Modeled as data
## now so that system exists in one place once it's built.
var maintenance_damage_threshold: int = -1

## L, M, P: arriving here calls for a Wolf Attack. Informational -
## GameState.start_wolf_attack() still has to be called by the host,
## never automatically (CLAUDE.md constraint 3).
var triggers_wolf_attack_on_arrival: bool = false
var wolf_attack_min_battlestations: int = 0
var wolf_attack_min_capacity: int = 0

## K only: unlike L/M/P's arrival trigger, K's Wolf Attack fires when
## the away mission *completes* without a critical success - a
## different condition, not just a different system, so it gets its
## own flag rather than overloading triggers_wolf_attack_on_arrival.
var triggers_wolf_attack_unless_critical: bool = false

## L, M only: the away mission can't be run while the Wolf base there
## is still operational.
var away_mission_blocked_while_wolf_base_operational: bool = false

## K only: difficulty is secretly rolled at runtime rather than fixed
## on the definition - see StarSystem.roll_hidden_difficulty().
var has_hidden_difficulty: bool = false

## N, O, P: bespoke non-card completion conditions instead of the
## standard away-mission opportunities above. Not modeled beyond this
## flag and descriptive text yet - see TODO.md.
var is_new_eden_candidate: bool = false
var new_eden_description: String = ""

static func from_dict(data: Dictionary) -> StarSystemDefinition:
	var definition := StarSystemDefinition.new()
	definition.letter = data["letter"]
	definition.display_name = data["display_name"]
	definition.rating = data.get("rating", "")
	definition.cards_dealt = data.get("cards_dealt", 0)
	definition.opportunities.assign(data.get("opportunities", []))
	definition.repeatable_each_turn = data.get("repeatable_each_turn", false)
	definition.suppresses_pursuit_reduction = data.get("suppresses_pursuit_reduction", false)
	definition.suppresses_pursuit_rise_while_present = data.get("suppresses_pursuit_rise_while_present", false)
	definition.maintenance_damage_threshold = data.get("maintenance_damage_threshold", -1)
	definition.triggers_wolf_attack_on_arrival = data.get("triggers_wolf_attack_on_arrival", false)
	definition.wolf_attack_min_battlestations = data.get("wolf_attack_min_battlestations", 0)
	definition.wolf_attack_min_capacity = data.get("wolf_attack_min_capacity", 0)
	definition.triggers_wolf_attack_unless_critical = data.get("triggers_wolf_attack_unless_critical", false)
	definition.away_mission_blocked_while_wolf_base_operational = data.get("away_mission_blocked_while_wolf_base_operational", false)
	definition.has_hidden_difficulty = data.get("has_hidden_difficulty", false)
	definition.is_new_eden_candidate = data.get("is_new_eden_candidate", false)
	definition.new_eden_description = data.get("new_eden_description", "")
	return definition
