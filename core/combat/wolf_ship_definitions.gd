class_name WolfShipDefinitions
extends RefCounted

## Static per-class Wolf ship data. Source: open_questions_answered.md
## §3.1 (roster/damage table), cross-checked against
## wolf_attack_tv_display.md's PREVENTS table (§5.3) - both agree.
##
## A Wolf ship's "capacity" is how much damage destroys it. Its damage
## output depends on *when* it dies: DAMAGE_IF_DESTROYED_AT[class][phase]
## is what it deals if killed during that range phase (its dying blow,
## dealt before it's removed); DAMAGE_IF_SURVIVES[class] is what it
## deals if it makes it through all three range phases to end-of-attack
## resolution. Killing a ship early doesn't erase damage already
## dealt in an earlier phase - the "prevents" number
## (WolfAttackView.prevents_for) is the difference between those two,
## i.e. how much *future* damage killing it now avoids.

enum Class { BATTLESTATION, STRIKECARRIER, CRUISER, DESTROYER, FIGHTER_WING, ASSAULT_TRANSPORT }
enum RangePhase { LONG, MEDIUM, SHORT }

const CLASS_NAMES: Dictionary[Class, String] = {
	Class.BATTLESTATION: "Battlestation",
	Class.STRIKECARRIER: "Strikecarrier",
	Class.CRUISER: "Cruiser",
	Class.DESTROYER: "Destroyer",
	Class.FIGHTER_WING: "Fighter Wing",
	Class.ASSAULT_TRANSPORT: "Assault Transport",
}

## Short two-letter/three-letter codes for the TV token display.
const CLASS_CODES: Dictionary[Class, String] = {
	Class.BATTLESTATION: "BS",
	Class.STRIKECARRIER: "SC",
	Class.CRUISER: "CR",
	Class.DESTROYER: "DE",
	Class.FIGHTER_WING: "FW",
	Class.ASSAULT_TRANSPORT: "AT",
}

## Damage points needed to destroy this class.
const CAPACITY: Dictionary[Class, int] = {
	Class.BATTLESTATION: 6,
	Class.STRIKECARRIER: 5,
	Class.CRUISER: 3,
	Class.DESTROYER: 2,
	Class.FIGHTER_WING: 1,
	Class.ASSAULT_TRANSPORT: 2,
}

## -1 means "cannot be damaged in this phase" (only the Battlestation
## at Short Range).
const DAMAGE_IF_DESTROYED_AT: Dictionary[Class, Dictionary] = {
	Class.BATTLESTATION: {RangePhase.LONG: 3, RangePhase.MEDIUM: 3, RangePhase.SHORT: -1},
	Class.STRIKECARRIER: {RangePhase.LONG: 2, RangePhase.MEDIUM: 2, RangePhase.SHORT: 2},
	Class.CRUISER: {RangePhase.LONG: 0, RangePhase.MEDIUM: 1, RangePhase.SHORT: 2},
	Class.DESTROYER: {RangePhase.LONG: 1, RangePhase.MEDIUM: 1, RangePhase.SHORT: 1},
	Class.FIGHTER_WING: {RangePhase.LONG: 0, RangePhase.MEDIUM: 0, RangePhase.SHORT: 1},
	Class.ASSAULT_TRANSPORT: {RangePhase.LONG: 0, RangePhase.MEDIUM: 0, RangePhase.SHORT: 0},
}

## Damage dealt at end-of-attack resolution if this ship survives every
## range phase. Assault Transports deal 0 direct damage here - they
## contribute boarding parties instead (BOARDING_PARTIES_IF_SURVIVES).
const DAMAGE_IF_SURVIVES: Dictionary[Class, int] = {
	Class.BATTLESTATION: 3,
	Class.STRIKECARRIER: 2,
	Class.CRUISER: 3,
	Class.DESTROYER: 2,
	Class.FIGHTER_WING: 1,
	Class.ASSAULT_TRANSPORT: 0,
}

## Only set for classes that actually return; absent (0) for the rest.
const BOARDING_PARTIES_IF_SURVIVES: Dictionary[Class, int] = {
	Class.ASSAULT_TRANSPORT: 4,
}

## Ships that come back for the next attack if they survive this one.
const RETURNS_IF_SURVIVES: Dictionary[Class, bool] = {
	Class.BATTLESTATION: true,
	Class.FIGHTER_WING: true,
}

## Immune (cannot take damage, cannot be destroyed) during these phases.
const IMMUNE_PHASES: Dictionary[Class, Array] = {
	Class.BATTLESTATION: [RangePhase.SHORT],
}

## 1d6 targeting roll -> which ship it hits. open_questions_answered.md
## §3.3. 1s and 6s wrap for the +/-1 shift abilities: "1s and 6s wrap
## around - 0s hit Refinery 124 and 7s hit the AEGIS."
const TARGETING_TABLE: Dictionary[int, String] = {
	1: "aegis",
	2: "dione",
	3: "icebreaker",
	4: "quellon",
	5: "shepherd",
	6: "refinery_124",
}

## Strikecarrier's secondary effect: if it survives to end-of-attack
## resolution, every surviving Wolf Fighter Wing deals +1 damage. Not a
## per-phase "prevents" number by itself - WolfAttackView computes its
## PREVENTS value as (live fighter wing count) at the moment of
## calculation, per wolf_attack_tv_display.md §5.3's note that it must
## be "recomputed every time a fighter wing dies".
const STRIKECARRIER_FIGHTER_BONUS := 1

static func class_name_for(wolf_class: Class) -> String:
	return CLASS_NAMES.get(wolf_class, "Unknown")

static func code_for(wolf_class: Class) -> String:
	return CLASS_CODES.get(wolf_class, "??")

static func capacity_for(wolf_class: Class) -> int:
	return CAPACITY.get(wolf_class, 0)

static func returns_if_survives(wolf_class: Class) -> bool:
	return RETURNS_IF_SURVIVES.get(wolf_class, false)

static func is_immune_at(wolf_class: Class, phase: RangePhase) -> bool:
	return phase in IMMUNE_PHASES.get(wolf_class, [])

## Damage this ship deals if destroyed during range_phase, or -1 if it
## cannot be damaged in that phase at all.
static func damage_if_destroyed_at(wolf_class: Class, range_phase: RangePhase) -> int:
	return DAMAGE_IF_DESTROYED_AT.get(wolf_class, {}).get(range_phase, 0)

static func damage_if_survives(wolf_class: Class) -> int:
	return DAMAGE_IF_SURVIVES.get(wolf_class, 0)

static func boarding_parties_if_survives(wolf_class: Class) -> int:
	return BOARDING_PARTIES_IF_SURVIVES.get(wolf_class, 0)
