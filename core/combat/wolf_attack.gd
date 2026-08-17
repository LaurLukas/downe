class_name WolfAttack
extends RefCounted

## One Wolf Attack in progress. This is bookkeeping and arithmetic
## only - it never decides targets, never resolves the fight, and
## never replaces the physical gathering at the battle table
## (CLAUDE.md constraint 3, wolf_attack_tv_display.md §1). The host
## drives every state change through the methods here; nothing
## advances on its own.
##
## Targeting dice ARE rolled by this class (via the caller's rng), not
## left for the host to type in - unlike scout coordinates or jump
## coordinates, a targeting roll has no deception potential to protect
## (it's fleet-vs-NPC, not player-vs-player), so it's automated the
## same way core/craft's combat_table ability already automates
## fighter/Maliades/Highwall damage rolls.

signal changed()

enum Phase { INCOMING, TARGETING, RANGE_LONG, RANGE_MEDIUM, RANGE_SHORT, BOARDING, RESOLUTION }
const PHASE_ORDER: Array[Phase] = [
	Phase.INCOMING, Phase.TARGETING, Phase.RANGE_LONG, Phase.RANGE_MEDIUM,
	Phase.RANGE_SHORT, Phase.BOARDING, Phase.RESOLUTION,
]

var phase: Phase = Phase.INCOMING
var turn_number: int = 1

## For system-triggered attacks that repeat until a Wolf base is
## destroyed (open question #4 in wolf_attack_tv_display.md §9) - each
## repeat is a new WolfAttack instance with this incremented, per the
## doc's own recommendation, rather than one instance looping back.
var round_number: int = 1

var wolf_ships: Dictionary[String, WolfShipState] = {}

## ship_id -> remaining Wolf boarding parties targeting it. Populated
## on entering BOARDING - see _start_boarding().
var boarders_by_ship: Dictionary[String, int] = {}

var wolf_commander_leading_boarding: bool = false
var wolf_commander_leading_boarding_ship_id: String = ""

var _next_index_by_class: Dictionary[WolfShipDefinitions.Class, int] = {}

func _init(starting_turn: int = 1, starting_round: int = 1) -> void:
	turn_number = starting_turn
	round_number = starting_round

## --- composition / targeting -------------------------------------

func add_wolf_ship(wolf_class: WolfShipDefinitions.Class, rng: RandomNumberGenerator) -> WolfShipState:
	var index: int = _next_index_by_class.get(wolf_class, 0) + 1
	_next_index_by_class[wolf_class] = index
	var id := "%s_%d" % [WolfShipDefinitions.code_for(wolf_class).to_lower(), index]
	var ship := WolfShipState.new(id, wolf_class)
	ship.changed.connect(changed.emit)
	# Pre-roll now, not on reveal - FG p10: lay out cards and pre-roll
	# targeting before announcing the attack. WolfAttackView is what's
	# responsible for keeping this hidden until the TARGETING phase.
	ship.set_target_die(rng.randi_range(1, 6))
	wolf_ships[id] = ship
	changed.emit()
	return ship

func get_wolf_ship(id: String) -> WolfShipState:
	return wolf_ships.get(id)

func reroll_target(id: String, rng: RandomNumberGenerator) -> void:
	var ship := get_wolf_ship(id)
	if ship != null:
		ship.set_target_die(rng.randi_range(1, 6))

## Fighter Wings/Maliades at medium range, and the Wolf Commander once
## per range phase - all shift by exactly 1, never roll.
func shift_target(id: String, delta: int) -> void:
	var ship := get_wolf_ship(id)
	if ship != null:
		ship.set_target_die(ship.target_die + delta)

## The AEGIS's Command and Control console - always forces the AEGIS
## itself as the new target, resolves after the Wolf Commander's
## re-roll (caller's responsibility to sequence that).
func force_target(id: String, ship_id: String) -> void:
	var ship := get_wolf_ship(id)
	if ship == null:
		return
	for die: int in WolfShipDefinitions.TARGETING_TABLE:
		if WolfShipDefinitions.TARGETING_TABLE[die] == ship_id:
			ship.set_target_die(die)
			return

## --- phase / damage -------------------------------------------------

func current_range_phase() -> WolfShipDefinitions.RangePhase:
	match phase:
		Phase.RANGE_LONG:
			return WolfShipDefinitions.RangePhase.LONG
		Phase.RANGE_MEDIUM:
			return WolfShipDefinitions.RangePhase.MEDIUM
		_:
			return WolfShipDefinitions.RangePhase.SHORT

func is_range_phase() -> bool:
	return phase in [Phase.RANGE_LONG, Phase.RANGE_MEDIUM, Phase.RANGE_SHORT]

## Generic damage tap - the host resolves whatever weapon dice
## (fleet console or craft) physically/mentally and applies the total
## here. Refuses to add damage during a phase this class is immune in
## (only the Battlestation at Short Range). delta may be negative to
## undo a miscount; undoing past the destroy threshold un-destroys it.
func add_damage(id: String, delta: int) -> void:
	var ship := get_wolf_ship(id)
	if ship == null:
		return
	if delta > 0 and is_range_phase() and WolfShipDefinitions.is_immune_at(ship.wolf_class, current_range_phase()):
		return
	var was_destroyed := ship.is_destroyed()
	ship.add_damage(delta)
	if not was_destroyed and ship.is_destroyed() and is_range_phase():
		ship.destroyed_at_phase = current_range_phase()
	elif was_destroyed and not ship.is_destroyed():
		ship.destroyed_at_phase = -1
	changed.emit()

func advance_phase() -> void:
	var index := PHASE_ORDER.find(phase)
	if index < 0 or index >= PHASE_ORDER.size() - 1:
		return
	phase = PHASE_ORDER[index + 1]
	if phase == Phase.BOARDING:
		_start_boarding()
	changed.emit()

## The host can move backwards - the display must never assume
## forward-only (wolf_attack_tv_display.md §5). Deliberately doesn't
## undo _start_boarding()'s side effects; boarder counts already
## decremented stay decremented, matching "undo means fix a miscount",
## not "replay the phase".
func retreat_phase() -> void:
	var index := PHASE_ORDER.find(phase)
	if index <= 0:
		return
	phase = PHASE_ORDER[index - 1]
	changed.emit()

## --- boarding ---------------------------------------------------------

func _start_boarding() -> void:
	boarders_by_ship.clear()
	for id: String in wolf_ships:
		var ship: WolfShipState = wolf_ships[id]
		if ship.is_destroyed():
			continue
		var parties := WolfShipDefinitions.boarding_parties_if_survives(ship.wolf_class)
		var target := ship.target_ship_id()
		if parties <= 0 or target.is_empty():
			continue
		boarders_by_ship[target] = boarders_by_ship.get(target, 0) + parties

func decrement_boarders(ship_id: String, amount: int = 1) -> void:
	if not boarders_by_ship.has(ship_id):
		return
	boarders_by_ship[ship_id] = maxi(boarders_by_ship[ship_id] - amount, 0)
	changed.emit()

## One-shot per attack - the Wolf Commander personally leading a
## boarding action, decided before the Pallas/Chepu abilities act.
func lead_boarding_with_commander(ship_id: String) -> void:
	if wolf_commander_leading_boarding:
		return
	wolf_commander_leading_boarding = true
	wolf_commander_leading_boarding_ship_id = ship_id
	boarders_by_ship[ship_id] = boarders_by_ship.get(ship_id, 0) + 2
	changed.emit()

func live_fighter_wing_count() -> int:
	var count := 0
	for id: String in wolf_ships:
		var ship: WolfShipState = wolf_ships[id]
		if ship.wolf_class == WolfShipDefinitions.Class.FIGHTER_WING and not ship.is_destroyed():
			count += 1
	return count

## --- damage tally -------------------------------------------------

## Just the subset of compute_damage_tally() that's already locked in -
## dying blows from ships destroyed during a range phase so far. Used
## for the "DAMAGE THIS ATTACK" readout during the attack (before
## RESOLUTION, surviving ships haven't dealt their damage yet).
func compute_damage_already_dealt() -> Dictionary:
	var damage_by_ship: Dictionary[String, int] = {}
	for id: String in wolf_ships:
		var ship: WolfShipState = wolf_ships[id]
		if ship.destroyed_at_phase == -1:
			continue
		var target := ship.target_ship_id()
		var dying_blow := WolfShipDefinitions.damage_if_destroyed_at(ship.wolf_class, ship.destroyed_at_phase)
		if dying_blow > 0 and not target.is_empty():
			damage_by_ship[target] = damage_by_ship.get(target, 0) + dying_blow
	return damage_by_ship

## Projected total damage each fleet ship takes if the attack ended
## right now: locked-in dying blows from ships already destroyed
## during a range phase, plus full damage from ships still alive
## (treated as "surviving" until proven otherwise). This is
## deliberately the same computation whether called mid-attack (as a
## live "incoming damage" readout) or at RESOLUTION (as the final
## tally) - nothing changes about how the numbers are derived, only
## whether more damage might still land before it's read again.
##
## Returns {"damage_by_ship": {ship_id: int}, "returning_counts":
## {WolfShipDefinitions.Class: int}}.
func compute_damage_tally() -> Dictionary:
	var damage_by_ship: Dictionary[String, int] = {}
	var returning_counts: Dictionary[WolfShipDefinitions.Class, int] = {}
	var surviving_strikecarriers := 0
	var surviving_fighter_wings: Array[WolfShipState] = []

	for id: String in wolf_ships:
		var ship: WolfShipState = wolf_ships[id]
		var target := ship.target_ship_id()

		if ship.destroyed_at_phase != -1:
			var dying_blow := WolfShipDefinitions.damage_if_destroyed_at(ship.wolf_class, ship.destroyed_at_phase)
			if dying_blow > 0 and not target.is_empty():
				damage_by_ship[target] = damage_by_ship.get(target, 0) + dying_blow
			continue

		if ship.is_destroyed():
			continue  # destroyed outside a range phase - no dying blow recorded

		# Still alive: treated as surviving to resolution.
		if WolfShipDefinitions.returns_if_survives(ship.wolf_class):
			returning_counts[ship.wolf_class] = returning_counts.get(ship.wolf_class, 0) + 1
		if ship.wolf_class == WolfShipDefinitions.Class.STRIKECARRIER:
			surviving_strikecarriers += 1
		if ship.wolf_class == WolfShipDefinitions.Class.FIGHTER_WING:
			surviving_fighter_wings.append(ship)
		var dmg := WolfShipDefinitions.damage_if_survives(ship.wolf_class)
		if dmg > 0 and not target.is_empty():
			damage_by_ship[target] = damage_by_ship.get(target, 0) + dmg

	if surviving_strikecarriers > 0:
		for fighter_wing: WolfShipState in surviving_fighter_wings:
			var target := fighter_wing.target_ship_id()
			if target.is_empty():
				continue
			damage_by_ship[target] = damage_by_ship.get(target, 0) + (surviving_strikecarriers * WolfShipDefinitions.STRIKECARRIER_FIGHTER_BONUS)

	return {"damage_by_ship": damage_by_ship, "returning_counts": returning_counts}

func to_dict() -> Dictionary:
	var ship_dict := {}
	for id: String in wolf_ships:
		ship_dict[id] = wolf_ships[id].to_dict()
	var next_index_dict := {}
	for cls: WolfShipDefinitions.Class in _next_index_by_class:
		next_index_dict[WolfShipDefinitions.Class.keys()[cls]] = _next_index_by_class[cls]
	return {
		"phase": Phase.keys()[phase],
		"turn_number": turn_number,
		"round_number": round_number,
		"wolf_ships": ship_dict,
		"boarders_by_ship": boarders_by_ship.duplicate(),
		"wolf_commander_leading_boarding": wolf_commander_leading_boarding,
		"wolf_commander_leading_boarding_ship_id": wolf_commander_leading_boarding_ship_id,
		"next_index_by_class": next_index_dict,
	}

static func from_dict(data: Dictionary) -> WolfAttack:
	var attack := WolfAttack.new(int(data.get("turn_number", 1)), int(data.get("round_number", 1)))
	attack.phase = Phase[data.get("phase", "INCOMING")]
	attack.wolf_commander_leading_boarding = bool(data.get("wolf_commander_leading_boarding", false))
	attack.wolf_commander_leading_boarding_ship_id = String(data.get("wolf_commander_leading_boarding_ship_id", ""))

	var boarders: Dictionary = data.get("boarders_by_ship", {})
	for ship_id: String in boarders:
		attack.boarders_by_ship[ship_id] = int(boarders[ship_id])

	var ship_dict: Dictionary = data.get("wolf_ships", {})
	for id: String in ship_dict:
		var ship := WolfShipState.from_dict(ship_dict[id])
		ship.changed.connect(attack.changed.emit)
		attack.wolf_ships[id] = ship

	var next_index: Dictionary = data.get("next_index_by_class", {})
	for class_name_key: String in next_index:
		attack._next_index_by_class[WolfShipDefinitions.Class[class_name_key]] = int(next_index[class_name_key])

	return attack
