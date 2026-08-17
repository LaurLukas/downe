class_name ResourceStock
extends RefCounted

## Tracks one ship's resource amounts. Moving resources between ships
## requires an appropriate shuttle - that constraint lives above this
## class (game_state/net), not here.

enum Kind { STRYTIUM_ORE, STRYTIUM_FUEL, FOOD, WATER, MATERIALS, SECURITY_TEAMS }

signal amount_changed(kind: Kind, new_amount: int)

var _amounts: Dictionary[Kind, int] = {}

func get_amount(kind: Kind) -> int:
	return _amounts.get(kind, 0)

func set_amount(kind: Kind, amount: int) -> void:
	_amounts[kind] = amount
	amount_changed.emit(kind, amount)

func add(kind: Kind, delta: int) -> void:
	set_amount(kind, get_amount(kind) + delta)

func to_dict() -> Dictionary:
	var out := {}
	for kind: Kind in _amounts:
		out[Kind.keys()[kind]] = _amounts[kind]
	return out

## Applies a to_dict()-shaped dict onto this stock in place, rather than
## building a new ResourceStock, so callers that already hold a
## reference wired into a parent's changed-bubbling (Ship, CraftState)
## don't need to rewire anything to load a save. See Ship.from_dict().
func load_from_dict(data: Dictionary) -> void:
	for kind_name: String in data:
		set_amount(Kind[kind_name], int(data[kind_name]))
