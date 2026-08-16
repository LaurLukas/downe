class_name FleetSetup
extends RefCounted

## Populates a fresh GameState with the six starting ships. Source:
## resources.md (DoWNE Facilitator Guide v1.0.1, p.5) for resources,
## security teams, and survivor population; open_questions_answered.md
## §2.2 for the console roster (transcribed from the A3 ship sheets).
##
## Consoles start undamaged and uncharged, and unrest starts at 0 -
## none of these are stated outright in the source, only implied by the
## role briefs (see open_questions_answered.md §2.4). Confirm before
## playtest.
##
## Out of scope here: the per-ship damage deck (each console's playing
## card, used to draw damage), console effects (Reactor charge counts,
## Missile Launchers, etc.), and the Maintenance Cycle step sequence
## that would actually charge/damage these consoles during play. Those
## are separate, larger systems - see TODO.md.

const STARTING_RESOURCES: Dictionary[String, Dictionary] = {
	"aegis": {
		ResourceStock.Kind.STRYTIUM_ORE: 0, ResourceStock.Kind.STRYTIUM_FUEL: 4,
		ResourceStock.Kind.FOOD: 8, ResourceStock.Kind.WATER: 6,
		ResourceStock.Kind.MATERIALS: 1, ResourceStock.Kind.SECURITY_TEAMS: 9,
	},
	"dione": {
		ResourceStock.Kind.STRYTIUM_ORE: 0, ResourceStock.Kind.STRYTIUM_FUEL: 3,
		ResourceStock.Kind.FOOD: 13, ResourceStock.Kind.WATER: 14,
		ResourceStock.Kind.MATERIALS: 0, ResourceStock.Kind.SECURITY_TEAMS: 2,
	},
	"icebreaker": {
		ResourceStock.Kind.STRYTIUM_ORE: 0, ResourceStock.Kind.STRYTIUM_FUEL: 4,
		ResourceStock.Kind.FOOD: 11, ResourceStock.Kind.WATER: 9,
		ResourceStock.Kind.MATERIALS: 3, ResourceStock.Kind.SECURITY_TEAMS: 2,
	},
	"shepherd": {
		ResourceStock.Kind.STRYTIUM_ORE: 0, ResourceStock.Kind.STRYTIUM_FUEL: 4,
		ResourceStock.Kind.FOOD: 10, ResourceStock.Kind.WATER: 8,
		ResourceStock.Kind.MATERIALS: 0, ResourceStock.Kind.SECURITY_TEAMS: 2,
	},
	"quellon": {
		ResourceStock.Kind.STRYTIUM_ORE: 0, ResourceStock.Kind.STRYTIUM_FUEL: 3,
		ResourceStock.Kind.FOOD: 10, ResourceStock.Kind.WATER: 8,
		ResourceStock.Kind.MATERIALS: 0, ResourceStock.Kind.SECURITY_TEAMS: 2,
	},
	"refinery_124": {
		ResourceStock.Kind.STRYTIUM_ORE: 12, ResourceStock.Kind.STRYTIUM_FUEL: 5,
		ResourceStock.Kind.FOOD: 9, ResourceStock.Kind.WATER: 4,
		ResourceStock.Kind.MATERIALS: 0, ResourceStock.Kind.SECURITY_TEAMS: 6,
	},
}

const STARTING_POPULATION: Dictionary[String, int] = {
	"aegis": 2500,
	"dione": 100000,
	"icebreaker": 40000,
	"shepherd": 30000,
	"quellon": 30000,
	"refinery_124": 20000,
}

## Console ids, snake_case versions of the names on each ship's sheet.
## Playing-card identity (A♥, 2♥, ...) is the damage-deck's concern, not
## modeled here yet.
const CONSOLE_ROSTER: Dictionary[String, Array] = {
	"aegis": [
		"fighter_bay_alpha", "fighter_bay_bravo", "command_and_control",
		"missile_launchers", "point_defence_lasers", "armoured_hull_i",
		"armoured_hull_ii", "storage", "jump_drive", "reactor",
		"construction_bay", "shuttle_bay_zeta", "shuttle_bay_omega",
	],
	"dione": [
		"storage", "reactor", "shuttle_bay", "hydroponics",
		"water_reclamation", "vip_lounge", "fighter_bay", "jump_drive",
	],
	"icebreaker": [
		"storage", "reactor", "shuttle_bay", "hydroponics",
		"water_reclamation", "mining_drone_control", "jump_drive", "ram_scoop",
	],
	"shepherd": [
		"storage", "reactor", "shuttle_bay", "water_reclamation",
		"advanced_hydroponics_i", "advanced_hydroponics_ii", "jump_drive",
	],
	"quellon": [
		"storage", "reactor", "shuttle_bay", "hydroponics",
		"water_production_i", "water_production_ii", "jump_drive",
	],
	"refinery_124": [
		"storage", "reactor", "shuttle_bay", "hydroponics",
		"water_reclamation", "fuel_refinery_i", "fuel_refinery_ii",
		"fighter_bay", "jump_drive",
	],
}

static func build_starting_fleet() -> GameState:
	var state := GameState.new()
	for ship_id: String in ShipRegistry.all_ship_ids():
		state.add_ship(build_ship(ship_id))
	return state

static func build_ship(ship_id: String) -> Ship:
	var ship := Ship.new(ship_id, ShipRegistry.is_scout_capable(ship_id))

	var starting_resources: Dictionary = STARTING_RESOURCES.get(ship_id, {})
	for kind: ResourceStock.Kind in starting_resources:
		ship.resources.set_amount(kind, starting_resources[kind])

	var population: int = STARTING_POPULATION.get(ship_id, 0)
	ship.survivor_population = population
	ship.max_survivor_population = population

	for console_id: String in CONSOLE_ROSTER.get(ship_id, []):
		ship.add_console(console_id)

	return ship
