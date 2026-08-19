class_name RevealState
extends RefCounted

## Claims (host-published scout reports, §6.4's "reported" chips) and
## host state overrides (§8's "Force state" escape hatch - CLAUDE.md
## constraint 5) for the star map. Never holds truth about an unvisited
## node - "visited" itself is derived from FleetPositions trails by
## whoever builds the projection, not stored here.
##
## A claim is a verbatim host-typed string, attributed to a source role
## and turn - never parsed, never matched against StarChart, never
## coloured by truth (constraint 1 / spec C3). Two scouts can claim the
## same node differently; both are kept, oldest first, so a
## contradiction stays visible instead of being resolved for the room
## ("show both chips stacked" - §6.4).

signal changed()

## coordinate -> Array[Dictionary] of {"text", "source", "turn"}.
var claims: Dictionary[String, Array] = {}

## coordinate -> forced node state string (e.g. "visited", "unknown"),
## absent for "not overridden - derive it normally".
var forced_states: Dictionary[String, String] = {}

func publish_claim(coordinate: String, text: String, source: String, turn: int) -> void:
	if not claims.has(coordinate):
		claims[coordinate] = []
	(claims[coordinate] as Array).append({"text": text, "source": source, "turn": turn})
	changed.emit()

func claims_at(coordinate: String) -> Array:
	return (claims.get(coordinate, []) as Array).duplicate(true)

## §8's "Retract claim" - by index into claims_at(coordinate), not by
## matching text, since two scouts can file byte-identical claims on
## purpose.
func retract_claim(coordinate: String, index: int) -> void:
	if not claims.has(coordinate):
		return
	var list: Array = claims[coordinate]
	if index < 0 or index >= list.size():
		return
	list.remove_at(index)
	if list.is_empty():
		claims.erase(coordinate)
	changed.emit()

func set_forced_state(coordinate: String, state: String) -> void:
	forced_states[coordinate] = state
	changed.emit()

func clear_forced_state(coordinate: String) -> void:
	if forced_states.has(coordinate):
		forced_states.erase(coordinate)
		changed.emit()

func to_dict() -> Dictionary:
	var claims_dict := {}
	for coordinate: String in claims:
		var list: Array = []
		for claim: Dictionary in (claims[coordinate] as Array):
			list.append(claim.duplicate())
		claims_dict[coordinate] = list
	return {
		"claims": claims_dict,
		"forced_states": forced_states.duplicate(),
	}

func load_from_dict(data: Dictionary) -> void:
	claims.clear()
	var raw_claims: Dictionary = data.get("claims", {})
	for coordinate: String in raw_claims:
		var list: Array = []
		for raw_claim: Variant in (raw_claims[coordinate] as Array):
			var claim: Dictionary = raw_claim
			list.append({
				"text": String(claim.get("text", "")),
				"source": String(claim.get("source", "")),
				"turn": int(claim.get("turn", 0)),
			})
		claims[coordinate] = list

	forced_states.clear()
	var raw_forced: Dictionary = data.get("forced_states", {})
	for coordinate: String in raw_forced:
		forced_states[coordinate] = String(raw_forced[coordinate])

static func from_dict(data: Dictionary) -> RevealState:
	var state := RevealState.new()
	state.load_from_dict(data)
	return state
