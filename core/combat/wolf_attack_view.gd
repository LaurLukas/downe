class_name WolfAttackView
extends RefCounted

## Pure view-builder: GameState (with an active wolf_attack) in, a
## plain Dictionary out, matching wolf_attack_tv_display.md §6's data
## contract. No Node/scene access, no mutation - build() can be called
## as often as needed (every GameState.mutated, same pattern as
## DisplayFormat/TVDisplay elsewhere) and never changes anything.
##
## Security boundary (§2): while phase is INCOMING, every wolf ship's
## "target" key is omitted from the dict entirely, not sent as null.
## The pre-rolled targets exist in WolfAttack the moment a ship is
## added (so the reveal can be instant once TARGETING starts), but
## nothing here renders them before that. A leak here is a leaked
## traitor mechanic.
##
## Scope note: live_fleet_weapons only covers what actually exists in
## the data model today - the AEGIS's two weapon consoles and the
## craft with a combat_table ability. Gorgoneion's Missile Array and
## Vulcan's Laser Cannon are Small Ship consoles, and Small Ships
## aren't modeled in core/ yet (TODO.md) - there is no object to check
## the charge/damage state of, so they can't appear here until that
## system exists.

const RANGE_PHASES: Dictionary[WolfAttack.Phase, WolfShipDefinitions.RangePhase] = {
	WolfAttack.Phase.RANGE_LONG: WolfShipDefinitions.RangePhase.LONG,
	WolfAttack.Phase.RANGE_MEDIUM: WolfShipDefinitions.RangePhase.MEDIUM,
	WolfAttack.Phase.RANGE_SHORT: WolfShipDefinitions.RangePhase.SHORT,
}

const PHASE_NAMES: Dictionary[WolfAttack.Phase, String] = {
	WolfAttack.Phase.INCOMING: "incoming",
	WolfAttack.Phase.TARGETING: "targeting",
	WolfAttack.Phase.RANGE_LONG: "range_long",
	WolfAttack.Phase.RANGE_MEDIUM: "range_medium",
	WolfAttack.Phase.RANGE_SHORT: "range_short",
	WolfAttack.Phase.BOARDING: "boarding",
	WolfAttack.Phase.RESOLUTION: "resolution",
}

## Craft ability id -> a short label for what it does at the battle
## table, for the fleet ship card's support_craft list.
## boarding_support_elite is Pallas only; boarding_support covers every
## other engineering/service shuttle that enables its docked ship's
## security teams to fight at all.
const SUPPORT_CRAFT_ABILITY_EFFECTS: Dictionary[String, String] = {
	"boarding_support_elite": "reroll_3",
	"boarding_support": "enables_defense",
}

const COMBAT_CRAFT_IDS: Array[String] = [
	"fighter_wing_alpha", "fighter_wing_bravo", "pdf_escort_wing", "maliades", "highwall",
]

static func build(game_state: GameState) -> Dictionary:
	var attack := game_state.wolf_attack
	if attack == null:
		return {}

	var targets_visible := attack.phase != WolfAttack.Phase.INCOMING
	var in_range_phase := RANGE_PHASES.has(attack.phase)
	var current_range: WolfShipDefinitions.RangePhase = RANGE_PHASES.get(attack.phase, WolfShipDefinitions.RangePhase.LONG)

	var tally := attack.compute_damage_tally()
	var damage_total: Dictionary = tally["damage_by_ship"]
	var damage_so_far: Dictionary = attack.compute_damage_already_dealt()
	var live_fighter_wings := attack.live_fighter_wing_count()

	var returning: Array[Dictionary] = []
	for cls: WolfShipDefinitions.Class in tally["returning_counts"]:
		returning.append({"class": WolfShipDefinitions.Class.keys()[cls].to_lower(), "count": tally["returning_counts"][cls]})

	return {
		"phase": PHASE_NAMES.get(attack.phase, ""),
		"turn": attack.turn_number,
		"round": attack.round_number,
		"pursuit": game_state.pursuit_track.value,
		"wolf_ships": _build_wolf_ships(attack, targets_visible, in_range_phase, current_range),
		"fleet_ships": _build_fleet_ships(game_state, attack, damage_total, damage_so_far),
		"live_fleet_weapons": _live_fleet_weapons(game_state, attack.phase),
		"returning": returning,
		"wolf_commander_leading_boarding": attack.wolf_commander_leading_boarding,
		"wolf_commander_leading_boarding_ship_id": attack.wolf_commander_leading_boarding_ship_id,
		"fighter_wings_alive": live_fighter_wings,
	}

static func _build_wolf_ships(attack: WolfAttack, targets_visible: bool, in_range_phase: bool, current_range: WolfShipDefinitions.RangePhase) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in attack.wolf_ships:
		var ship: WolfShipState = attack.wolf_ships[id]
		var immune_this_phase := in_range_phase and WolfShipDefinitions.is_immune_at(ship.wolf_class, current_range)
		var entry := {
			"id": ship.id,
			"class": WolfShipDefinitions.Class.keys()[ship.wolf_class].to_lower(),
			"capacity": ship.capacity(),
			"damage_taken": ship.damage_taken,
			"destroyed": ship.is_destroyed(),
			# -1 = still alive, or destroyed outside a range phase. Used by
			# the damage-ladder redesign to show a destroyed wolf's actually
			# realised cell (docs/wolf_attack_damage_ladder.md §6's "resolve"
			# rule, extended here to any phase a wolf is already destroyed
			# in, not just RESOLUTION - once a ship is destroyed its ladder
			# outcome is locked in regardless of what phase is current now).
			"destroyed_at_phase": ship.destroyed_at_phase,
			"returns_if_survives": WolfShipDefinitions.returns_if_survives(ship.wolf_class),
			"immune_this_phase": immune_this_phase,
		}
		if targets_visible:
			entry["target"] = ship.target_ship_id()

		out.append(entry)
	return out

static func _build_fleet_ships(game_state: GameState, attack: WolfAttack, damage_total: Dictionary, damage_so_far: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ship_id: String in ShipRegistry.all_ship_ids():
		var ship := game_state.get_ship(ship_id)
		if ship == null:
			continue
		var resolved := attack.phase == WolfAttack.Phase.RESOLUTION
		var incoming: int = 0 if resolved else int(damage_total.get(ship_id, 0))
		var so_far: int = int(damage_total.get(ship_id, 0)) if resolved else int(damage_so_far.get(ship_id, 0))
		var boarders_inbound: int = attack.boarders_by_ship.get(ship_id, 0)
		var security_teams := ship.resources.get_amount(ResourceStock.Kind.SECURITY_TEAMS)
		out.append({
			"id": ship_id,
			"incoming_damage": incoming,
			"damage_this_attack": so_far,
			"security_teams": security_teams,
			"boarders_inbound": boarders_inbound,
			"support_craft": _support_craft_for(game_state, ship_id),
			"critical": boarders_inbound > security_teams,
		})
	return out

static func _support_craft_for(game_state: GameState, ship_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for craft_id: String in game_state.craft:
		var craft_state: CraftState = game_state.craft[craft_id]
		if craft_state.docked_ship_id != ship_id:
			continue
		var definition := CraftDefinitions.get_definition(craft_id)
		if definition == null:
			continue
		for ability_id: String in SUPPORT_CRAFT_ABILITY_EFFECTS:
			if ability_id in definition.ability_ids:
				out.append({"id": craft_id, "effect": SUPPORT_CRAFT_ABILITY_EFFECTS[ability_id]})
				break
	return out

static func _live_fleet_weapons(game_state: GameState, phase: WolfAttack.Phase) -> Array[String]:
	var weapons: Array[String] = []
	if not RANGE_PHASES.has(phase):
		return weapons
	var range_phase: WolfShipDefinitions.RangePhase = RANGE_PHASES[phase]

	var aegis := game_state.get_ship("aegis")
	if aegis != null:
		var at_long_or_medium := range_phase == WolfShipDefinitions.RangePhase.LONG or range_phase == WolfShipDefinitions.RangePhase.MEDIUM
		var at_medium_or_short := range_phase == WolfShipDefinitions.RangePhase.MEDIUM or range_phase == WolfShipDefinitions.RangePhase.SHORT
		if at_long_or_medium and _console_ready(aegis, "missile_launchers"):
			weapons.append("aegis_missile_launchers")
		if at_medium_or_short and _console_ready(aegis, "point_defence_lasers"):
			weapons.append("aegis_point_defence_lasers")

	if range_phase == WolfShipDefinitions.RangePhase.MEDIUM or range_phase == WolfShipDefinitions.RangePhase.SHORT:
		var range_band := CombatTableAbility.RangeBand.MEDIUM if range_phase == WolfShipDefinitions.RangePhase.MEDIUM else CombatTableAbility.RangeBand.SHORT
		var combat_table := AbilityRegistry.get_ability("combat_table")
		for craft_id: String in COMBAT_CRAFT_IDS:
			if game_state.get_craft(craft_id) == null:
				continue
			if combat_table.can_execute(game_state, craft_id, {"range": range_band}).ok:
				weapons.append(craft_id)

	return weapons

static func _console_ready(ship: Ship, console_id: String) -> bool:
	var console := ship.get_console(console_id)
	return console != null and console.charged and console.state == Console.State.OK
