class_name ShipRegistry
extends RefCounted

## Single lookup table for ship display names and fixed roster facts.
## Logic elsewhere should key off snake_case ids and call display_name()
## rather than hardcoding names.

## The six capital ships - the only ones with independent resource pools.
## "Endeavour", "Maliades", and "Pallas" are craft names (Shepherd's
## scout, Dione's escort fighter, AEGIS's assault shuttle respectively,
## per downe_shuttle_implementation_prompt.md's roster) - not ships.
## Confirmed against resources.md, whose starting-resources table only
## covers these six.
const DISPLAY_NAMES: Dictionary[String, String] = {
	"aegis": "AEGIS",
	"dione": "Dione",
	"icebreaker": "Icebreaker",
	"shepherd": "Shepherd",
	"quellon": "Quellon",
	"refinery_124": "Refinery 124",
}

## Ships with a scout craft docked: AEGIS (Starlight), Shepherd
## (Endeavour, crewed by the Scientist), Quellon (Hummingbird, crewed by
## the Explorer).
const SCOUT_CAPABLE: Dictionary[String, bool] = {
	"aegis": true,
	"shepherd": true,
	"quellon": true,
}

static func display_name(ship_id: String) -> String:
	return DISPLAY_NAMES.get(ship_id, ship_id)

static func is_scout_capable(ship_id: String) -> bool:
	return SCOUT_CAPABLE.get(ship_id, false)

static func all_ship_ids() -> Array[String]:
	return DISPLAY_NAMES.keys()
