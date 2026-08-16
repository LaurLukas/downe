class_name CombatTableAbility
extends Ability

## Reference data plus arithmetic helpers only - never an automated
## resolver. Wolf Attacks stay a physical gathering at the battle
## table (CLAUDE.md constraint 3); this rolls the dice a profile calls
## for and totals hits/damage/losses on request, exactly like a
## calculator, and it never picks targets or decides the outcome of
## the attack.
##
## Only Maliades, Highwall, and the three fighter wings carry this
## ability. Secondary effects not modeled here: Maliades' and the
## fighter wings' medium-range "shift a Wolf ship's target number"
## option (that mutates a Wolf ship, which has no model yet - see
## TODO.md's Wolf Attack data), and repairing Maliades' damage in a
## Shuttle Bay during Team Phase (no Maintenance Cycle exists yet).
##
## params: {range: RangeBand}

enum RangeBand { MEDIUM, SHORT }

## Fighter wing id -> home-ship console ids where any one, charged and
## undamaged, lets it launch. Alpha and Bravo may launch from either of
## the AEGIS's two bays.
const FIGHTER_BAY_CONSOLES := {
	"fighter_wing_alpha": ["fighter_bay_alpha", "fighter_bay_bravo"],
	"fighter_wing_bravo": ["fighter_bay_alpha", "fighter_bay_bravo"],
	"pdf_escort_wing": ["fighter_bay"],
}

func can_execute(game_state: GameState, craft_id: String, _params: Dictionary) -> AbilityCheck:
	var craft_state := game_state.get_craft(craft_id)
	if craft_state == null:
		return AbilityCheck.denied("no such craft")
	var definition := CraftDefinitions.get_definition(craft_id)
	if not "combat_table" in definition.ability_ids:
		return AbilityCheck.denied("this craft has no combat profile")

	if craft_id == "highwall" and not craft_state.fuelled:
		return AbilityCheck.denied("not fuelled - Highwall requires fuel to attend the combat table")

	if definition.craft_class == CraftDefinition.Class.FIGHTER_WING:
		if craft_state.fighter_count <= 0:
			return AbilityCheck.denied("no fighters remaining")
		if not _has_charged_bay(game_state, craft_id, definition):
			return AbilityCheck.denied("no charged, undamaged fighter bay to launch from")
	elif definition.max_combat_damage >= 0 and craft_state.combat_damage >= definition.max_combat_damage:
		return AbilityCheck.denied("craft destroyed")

	return AbilityCheck.allowed()

func execute(game_state: GameState, craft_id: String, params: Dictionary) -> AbilityResult:
	var check := can_execute(game_state, craft_id, params)
	if not check.ok:
		return AbilityResult.failure(check.reason)

	var craft_state := game_state.get_craft(craft_id)
	var definition := CraftDefinitions.get_definition(craft_id)
	var range_band: RangeBand = params.get("range", RangeBand.MEDIUM)

	if craft_id == "maliades":
		return _resolve_maliades(game_state, craft_state, range_band)
	if craft_id == "highwall":
		return _resolve_highwall(game_state, range_band)
	if definition.craft_class == CraftDefinition.Class.FIGHTER_WING:
		return _resolve_fighter_wing(game_state, craft_state, range_band)
	return AbilityResult.failure("no combat resolution defined for this craft")

func _has_charged_bay(game_state: GameState, craft_id: String, definition: CraftDefinition) -> bool:
	var home_ship := game_state.get_ship(definition.home_ship)
	if home_ship == null:
		return false
	for bay_id: String in FIGHTER_BAY_CONSOLES.get(craft_id, []):
		var console := home_ship.get_console(bay_id)
		if console != null and console.charged and console.state == Console.State.OK:
			return true
	return false

## Medium: 1 die, 4+ hits for 1 damage; 1-3 instead deals this craft 1
## self-damage. Short: 2 dice, each 2+ hits for 1 damage, each 1 deals
## 1 self-damage.
func _resolve_maliades(game_state: GameState, craft_state: CraftState, range_band: RangeBand) -> AbilityResult:
	var hits := 0
	var self_damage := 0
	var dice_count := 1 if range_band == RangeBand.MEDIUM else 2
	var self_damage_on_or_below := 3 if range_band == RangeBand.MEDIUM else 1

	for i in dice_count:
		var roll := game_state.rng.randi_range(1, 6)
		if roll <= self_damage_on_or_below:
			self_damage += 1
		else:
			hits += 1

	if self_damage > 0:
		craft_state.set_combat_damage(craft_state.combat_damage + self_damage)

	var max_damage := CraftDefinitions.get_definition("maliades").max_combat_damage
	return AbilityResult.success({
		"hits": hits,
		"damage_dealt": hits,
		"self_damage": self_damage,
		"combat_damage": craft_state.combat_damage,
		"destroyed": craft_state.combat_damage >= max_damage,
	})

## Both ranges: 1 die, 5+ hits for 3 damage. No self-damage - Highwall
## has no stated damage track.
func _resolve_highwall(game_state: GameState, _range_band: RangeBand) -> AbilityResult:
	var roll := game_state.rng.randi_range(1, 6)
	var hit := roll >= 5
	return AbilityResult.success({"hits": 1 if hit else 0, "damage_dealt": 3 if hit else 0})

## Per fighter, medium: 1 die, 5+ hits for 1 damage. Short: 1 die, 3+
## hits for 1 damage, 1-2 instead destroys that fighter. Assumes every
## fighter attacks rather than shifting a Wolf ship's target number -
## the target-shift choice isn't modeled (see class comment).
func _resolve_fighter_wing(game_state: GameState, craft_state: CraftState, range_band: RangeBand) -> AbilityResult:
	var hits := 0
	var fighters_lost := 0

	for i in craft_state.fighter_count:
		var roll := game_state.rng.randi_range(1, 6)
		if range_band == RangeBand.MEDIUM:
			if roll >= 5:
				hits += 1
		else:
			if roll <= 2:
				fighters_lost += 1
			else:
				hits += 1

	if fighters_lost > 0:
		craft_state.set_fighter_count(craft_state.fighter_count - fighters_lost)

	return AbilityResult.success({
		"hits": hits,
		"damage_dealt": hits,
		"fighters_lost": fighters_lost,
		"fighter_count": craft_state.fighter_count,
	})
