class_name Console
extends RefCounted

## One damageable/repairable/upgradeable subsystem on a ship
## (e.g. "engines", "shields", "comms").

enum State { OK, DAMAGED, DESTROYED }

signal state_changed(new_state: State)
signal upgrade_changed(new_level: int)
signal charged_changed(is_charged: bool)

var id: String
var state: State = State.OK
var upgrade_level: int = 0

## Charge is spent by the Reactor during the Maintenance Cycle and is
## separate from state - a console can be OK but uncharged. Unused
## charge is lost at the end of every turn regardless of whether it was
## spent (see CLAUDE.md's Turn phase structure).
var charged: bool = false

func _init(console_id: String) -> void:
	id = console_id

func set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)

func set_charged(is_charged: bool) -> void:
	charged = is_charged
	charged_changed.emit(is_charged)

func damage() -> void:
	set_state(State.DAMAGED)

func destroy() -> void:
	set_state(State.DESTROYED)

func repair() -> void:
	set_state(State.OK)

func upgrade() -> void:
	upgrade_level += 1
	upgrade_changed.emit(upgrade_level)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"state": State.keys()[state],
		"upgrade_level": upgrade_level,
		"charged": charged,
	}

## Applies a to_dict()-shaped dict onto this console in place - see
## ResourceStock.load_from_dict() for why callers use this instead of a
## static from_dict() that would return a fresh, unwired instance.
func load_from_dict(data: Dictionary) -> void:
	state = State[data.get("state", "OK")]
	upgrade_level = int(data.get("upgrade_level", 0))
	charged = bool(data.get("charged", false))
