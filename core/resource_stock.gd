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
