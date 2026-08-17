class_name MaintenanceCycle
extends RefCounted

## The Team Phase's internal step sequence, run once per ship per Team
## Phase - open_questions_answered.md §5.2. Each ship's table works
## through its own steps at its own pace ("run per ship in parallel,
## not fleet-wide in lockstep"); this only provides the arithmetic each
## step needs and a per-ship checklist (Ship.completed_maintenance_steps)
## so a table doesn't lose track of where it is.
##
## Scope: this automates dice rolls and resource spending (no
## deception potential - same reasoning already applied to Wolf Attack
## targeting and combat rolls), but does not decide *which specific
## console* takes riot damage. Every console has its own printed
## playing card and damage is dealt by drawing from a finite per-ship
## deck (§2.1: "the damage deck is the console index... this is
## load-bearing - model the deck, not a random console picker"). That
## deck is physical, matching how Wolf Attack damage resolution already
## leaves "which console" to the host marking the existing per-console
## override - simulating a virtual deck here would mean building a
## second copy of a system the physical cards already are the source
## of truth for. The host marks the drawn console via HostConsole's
## existing per-ship console panel, informed by roll_riot_damage()'s
## result.

enum Step { STORAGE, RATIONS, UNREST_ROLL, RIOT_ROLL, REACTOR, SHUTTLE_BAY, SHUTTLE_BAY_OMEGA }

const STEP_LABELS: Dictionary[Step, String] = {
	Step.STORAGE: "1. Storage",
	Step.RATIONS: "2. Rations",
	Step.UNREST_ROLL: "3. Unrest roll",
	Step.RIOT_ROLL: "4. Riot roll",
	Step.REACTOR: "5. Reactor",
	Step.SHUTTLE_BAY: "6. Shuttle Bay",
	Step.SHUTTLE_BAY_OMEGA: "7. Shuttle Bay Omega",
}

## AEGIS is the only ship with a 7th step (a second Shuttle Bay refuel,
## via a separate console - see SHUTTLE_BAY_CONSOLE_ID). Every other
## ship runs steps 1-6.
const DEFAULT_STEPS: Array[Step] = [
	Step.STORAGE, Step.RATIONS, Step.UNREST_ROLL, Step.RIOT_ROLL, Step.REACTOR, Step.SHUTTLE_BAY,
]
const AEGIS_STEPS: Array[Step] = [
	Step.STORAGE, Step.RATIONS, Step.UNREST_ROLL, Step.RIOT_ROLL, Step.REACTOR, Step.SHUTTLE_BAY, Step.SHUTTLE_BAY_OMEGA,
]

## Every ship's Shuttle Bay console id - AEGIS has two distinct bays
## (Zeta for step 6, Omega for step 7); every other ship has one.
const SHUTTLE_BAY_CONSOLE_ID: Dictionary[String, String] = {
	"aegis": "shuttle_bay_zeta",
}
const SHUTTLE_BAY_OMEGA_CONSOLE_ID := "shuttle_bay_omega"
const DEFAULT_SHUTTLE_BAY_CONSOLE_ID := "shuttle_bay"

## Step 5: how many consoles the Reactor can charge, before
## upgrade/damage - ships.md's "Reactor charges vs. console count", not
## the rougher "-2 or -3" summary in open_questions_answered.md, which
## is ambiguous about which ships get which penalty. Cross-checked
## against each ship's own Reactor console entry in ships.md, which
## states this per-ship, unambiguously.
const REACTOR_CHARGE_CAP: Dictionary[String, int] = {
	"aegis": 5, "dione": 4, "icebreaker": 4, "refinery_124": 4,
	"shepherd": 3, "quellon": 3,
}
const REACTOR_DAMAGED_PENALTY: Dictionary[String, int] = {
	"aegis": 3, "dione": 3, "icebreaker": 3, "refinery_124": 3,
	"shepherd": 2, "quellon": 2,
}

## Step 2: ration level index 0 (none) .. 3 (normal) -> resource cost.
## open_questions_answered.md §2.3.
const FOOD_RATION_COST: Dictionary[String, Array] = {
	"aegis": [0, 3, 5, 8], "dione": [0, 6, 12, 18], "icebreaker": [0, 4, 9, 13],
	"shepherd": [0, 4, 8, 12], "quellon": [0, 4, 8, 12], "refinery_124": [0, 3, 7, 11],
}
const WATER_RATION_COST: Dictionary[String, Array] = {
	"aegis": [0, 2, 3, 6], "dione": [0, 6, 11, 14], "icebreaker": [0, 4, 7, 10],
	"shepherd": [0, 3, 6, 9], "quellon": [0, 3, 6, 9], "refinery_124": [0, 2, 5, 8],
}
## Same bonus scale for every ship, both food and water - only the
## costs vary per ship.
const RATION_BONUS: Array[int] = [0, 3, 6, 9]

static func steps_for(ship_id: String) -> Array[Step]:
	return AEGIS_STEPS if ship_id == "aegis" else DEFAULT_STEPS

static func shuttle_bay_console_id(ship_id: String) -> String:
	return SHUTTLE_BAY_CONSOLE_ID.get(ship_id, DEFAULT_SHUTTLE_BAY_CONSOLE_ID)

## Step 1: if the Storage console is damaged, half the ship's resources
## (and any docked shuttles' cargo) are discarded. Already built - see
## StorageDamage's own file for the rounding rule.
static func apply_storage_step(game_state: GameState, ship_id: String) -> void:
	StorageDamage.apply_if_damaged(game_state, ship_id)

## Step 2: spend the chosen ration level's cost from food and water
## independently; returns the combined bonus step 3's roll gets.
## level is 0 (none) .. 3 (normal).
static func spend_rations(game_state: GameState, ship_id: String, food_level: int, water_level: int) -> int:
	var ship := game_state.get_ship(ship_id)
	if ship == null:
		return 0
	var food_cost: int = FOOD_RATION_COST.get(ship_id, [0, 0, 0, 0])[food_level]
	var water_cost: int = WATER_RATION_COST.get(ship_id, [0, 0, 0, 0])[water_level]
	ship.resources.add(ResourceStock.Kind.FOOD, -food_cost)
	ship.resources.add(ResourceStock.Kind.WATER, -water_cost)
	return RATION_BONUS[food_level] + RATION_BONUS[water_level]

## Step 3: roll 2d6 + the ration bonus from step 2. Under 12 -> +2
## unrest. Under 20 (but >= 12) -> +1 unrest. 20+ -> no gain. Applies
## the gain directly and returns the roll details for display.
static func roll_unrest_gain(game_state: GameState, ship_id: String, ration_bonus: int) -> Dictionary:
	var ship := game_state.get_ship(ship_id)
	if ship == null:
		return {}
	var dice := game_state.rng.randi_range(1, 6) + game_state.rng.randi_range(1, 6)
	var total := dice + ration_bonus
	var gain := 0
	if total < 12:
		gain = 2
	elif total < 20:
		gain = 1
	if gain > 0:
		ship.set_unrest(ship.unrest + gain)
	return {"dice": dice, "ration_bonus": ration_bonus, "total": total, "unrest_gain": gain}

## Step 4: roll 1d6; if it's lower than the ship's *current* unrest, the
## ship takes 1 damage from rioting. Which console specifically is
## drawn from the ship's physical damage deck - see class comment; the
## host marks it via the existing per-console override once this
## returns whether a hit landed.
static func roll_riot_damage(game_state: GameState, ship_id: String) -> Dictionary:
	var ship := game_state.get_ship(ship_id)
	if ship == null:
		return {}
	var roll := game_state.rng.randi_range(1, 6)
	var damaged := roll < ship.unrest
	return {"roll": roll, "unrest": ship.unrest, "damaged": damaged}

## Step 5 reference numbers only - charging a specific console is still
## the host/player's choice, done through the existing per-console
## "charged" override (HostConsole already has this). This just answers
## "how many can we charge" and "how many have we charged so far" so
## the host doesn't have to compute the cap by hand. Never enforced as
## a hard block - CLAUDE.md constraint 5, the host can always override.
static func reactor_charge_cap(ship: Ship) -> int:
	var reactor := ship.get_console("reactor")
	if reactor == null:
		return 0
	if reactor.state == Console.State.DESTROYED:
		return 0
	var cap: int = REACTOR_CHARGE_CAP.get(ship.id, 0) + reactor.upgrade_level
	if reactor.state == Console.State.DAMAGED:
		cap -= REACTOR_DAMAGED_PENALTY.get(ship.id, 0)
	return maxi(cap, 0)

static func charged_console_count(ship: Ship) -> int:
	var count := 0
	for console_id: String in ship.consoles:
		if ship.consoles[console_id].charged:
			count += 1
	return count

## Steps 6/7: spend 1 strytium fuel to refuel one docked shuttle,
## through the given Shuttle Bay console (shuttle_bay_console_id() /
## SHUTTLE_BAY_OMEGA_CONSOLE_ID for AEGIS's second one). A damaged bay
## cannot refuel.
static func can_refuel_shuttle(ship: Ship, bay_console_id: String) -> bool:
	var bay := ship.get_console(bay_console_id)
	if bay == null or bay.state != Console.State.OK:
		return false
	return ship.resources.get_amount(ResourceStock.Kind.STRYTIUM_FUEL) >= 1

static func refuel_shuttle(game_state: GameState, ship_id: String, craft_id: String, bay_console_id: String) -> bool:
	var ship := game_state.get_ship(ship_id)
	var craft_state := game_state.get_craft(craft_id)
	if ship == null or craft_state == null or craft_state.docked_ship_id != ship_id:
		return false
	if not can_refuel_shuttle(ship, bay_console_id):
		return false
	ship.resources.add(ResourceStock.Kind.STRYTIUM_FUEL, -1)
	craft_state.set_fuelled(true)
	return true

## --- Small Ships' 4-step cycle - data only, not wired to anything.
## Small Ships (Gorgoneion, Capybara, Warrior, Vulcan, Voyage 33-0)
## aren't modeled as Ship objects in core/ yet (see TODO.md), so there's
## nothing for these steps to execute against. Kept here as reference
## for whenever that system is built: no Storage step; the riot step
## (3) differs from core ships' - instead of console damage, the ship
## loses population equal to the die value and skips step 4 (charge)
## that turn.
enum SmallShipStep { RATIONS, UNREST_ROLL, RIOT_ROLL, REACTOR }
const SMALL_SHIP_STEPS: Array[SmallShipStep] = [
	SmallShipStep.RATIONS, SmallShipStep.UNREST_ROLL, SmallShipStep.RIOT_ROLL, SmallShipStep.REACTOR,
]
